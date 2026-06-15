import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createSign } from "node:crypto";

const __dirname = dirname(fileURLToPath(import.meta.url));
const config = await readConfig();
const port = Number(process.env.PORT || config.port || 8810);
const googleSheetId = process.env.GOOGLE_SHEET_ID || config.googleSheetId;
const googleServiceAccountFile = process.env.GOOGLE_SERVICE_ACCOUNT_FILE || config.googleServiceAccountFile;
const googleServiceAccountJson = process.env.GOOGLE_SERVICE_ACCOUNT_JSON;
const databaseUrl = process.env.DATABASE_URL || config.databaseUrl;
const pool = await createPool(databaseUrl);
let cachedToken = null;

async function readConfig() {
  try {
    return JSON.parse(await readFile(join(__dirname, "googleSheets.config.json"), "utf8"));
  } catch {
    return {};
  }
}

async function createPool(url) {
  if (!url) return null;
  try {
    const pg = await import("pg");
    return new pg.Pool({ connectionString: url });
  } catch (error) {
    console.warn(`PostgreSQL mirror disabled: ${error.message}`);
    return null;
  }
}

function sendJson(res, status, payload) {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type"
  });
  res.end(JSON.stringify(payload));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => resolve(body ? JSON.parse(body) : {}));
    req.on("error", reject);
  });
}

function base64url(value) {
  return Buffer.from(value).toString("base64").replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function getGoogleToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60000) return cachedToken.token;
  if (!googleServiceAccountJson && !googleServiceAccountFile) throw new Error("Missing GOOGLE_SERVICE_ACCOUNT_FILE or GOOGLE_SERVICE_ACCOUNT_JSON.");
  const account = JSON.parse(googleServiceAccountJson || await readFile(googleServiceAccountFile, "utf8"));
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/spreadsheets",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  }));
  const body = `${header}.${claim}`;
  const signature = createSign("RSA-SHA256").update(body).sign(account.private_key, "base64url");
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${body}.${signature}` })
  });
  if (!response.ok) throw new Error(`Google auth failed: ${response.status}`);
  const data = await response.json();
  cachedToken = { token: data.access_token, expiresAt: Date.now() + (data.expires_in || 3600) * 1000 };
  return cachedToken.token;
}

async function sheetsFetch(path, options = {}) {
  const token = await getGoogleToken();
  const response = await fetch(`https://sheets.googleapis.com/v4/spreadsheets/${googleSheetId}${path}`, {
    ...options,
    headers: { "content-type": "application/json", authorization: `Bearer ${token}`, ...(options.headers || {}) }
  });
  if (!response.ok) throw new Error(await response.text());
  return response.json();
}

async function getSheetData() {
  const ranges = ["'Company Owned Items'!A1:AE1000", "'OS Debts'!A1:AG999", "'Active Pawns'!A1:AG991", "'Damaged goods'!A1:Z1000"];
  const params = new URLSearchParams();
  ranges.forEach(range => params.append("ranges", range));
  const data = await sheetsFetch(`/values:batchGet?${params}`);
  const values = Object.fromEntries((data.valueRanges || []).map(range => [range.range.split("!")[0].replaceAll("'", ""), range.values || []]));
  const sheetData = {
    syncedAt: new Date().toISOString(),
    source: "Google Sheets: NEW ONE",
    companyOwnedItems: values["Company Owned Items"] || [],
    osDebts: values["OS Debts"] || [],
    activePawns: values["Active Pawns"] || [],
    damagedGoods: values["Damaged goods"] || []
  };
  await mirrorSheetSnapshot(sheetData);
  return sheetData;
}

async function batchUpdate(updates, metadata = {}) {
  await recordSyncJob("sheet_batch_update", { updates, metadata }, "pending");
  const result = await sheetsFetch("/values:batchUpdate", {
    method: "POST",
    body: JSON.stringify({ valueInputOption: "USER_ENTERED", data: updates.map(update => ({ range: update.range, values: update.values })) })
  });
  await recordSyncJob("sheet_batch_update", { updates, metadata, result }, "synced");
  return result;
}

async function mirrorSheetSnapshot(data) {
  if (!pool) return;
  await pool.query(
    `insert into sheet_snapshots (source, synced_at, payload)
     values ($1, $2, $3)`,
    [data.source, data.syncedAt, data]
  );
  await mirrorLoans("Active Pawns", data.activePawns || []);
  await mirrorLoans("OS Debts", data.osDebts || []);
  await mirrorInventory(data.companyOwnedItems || []);
}

function toObjects(rows) {
  const [headers, ...body] = rows || [[]];
  return body
    .map((row, index) => ({ row, rowNumber: index + 2 }))
    .filter(entry => entry.row?.some(cell => cell !== null && cell !== undefined && String(cell).trim() !== ""))
    .filter(entry => String(entry.row[0] || "").trim().toLowerCase() !== "totals")
    .map(entry => ({ ...Object.fromEntries(headers.map((h, i) => [String(h || `Column ${i + 1}`).trim(), entry.row[i] ?? null])), __rowNumber: entry.rowNumber, __row: entry.row }));
}

function parseNumber(value) {
  const match = String(value ?? "").replace(/,/g, "").match(/-?\d+(\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

function parseDate(value) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString().slice(0, 10);
}

async function mirrorLoans(sheetName, rows) {
  for (const row of toObjects(rows)) {
    const loanAmount = parseNumber(row["Loan Amount"]);
    const interestAmount = parseNumber(row["Interest Amount"]);
    const totalPayback = parseNumber(row["Total Payback"]) || loanAmount + interestAmount;
    const amountPaid = parseNumber(row["Amount Paid"]);
    const remainingBalance = parseNumber(row["Remaining Balance"]) || Math.max(totalPayback - amountPaid, 0);
    await pool.query(
      `insert into loans
        (sheet_name, row_number, client_name, item_pawned, loan_amount, interest_amount, total_payback, amount_paid, remaining_balance, due_date, date_given, location, payload)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
       on conflict (sheet_name, row_number) do update set
        client_name = excluded.client_name,
        item_pawned = excluded.item_pawned,
        loan_amount = excluded.loan_amount,
        interest_amount = excluded.interest_amount,
        total_payback = excluded.total_payback,
        amount_paid = excluded.amount_paid,
        remaining_balance = excluded.remaining_balance,
        due_date = excluded.due_date,
        date_given = excluded.date_given,
        location = excluded.location,
        payload = excluded.payload,
        updated_at = now()`,
      [
        sheetName,
        row.__rowNumber,
        row["Client Name"] || null,
        row["Item Pawned"] || row["Column 1"] || null,
        loanAmount,
        interestAmount,
        totalPayback,
        amountPaid,
        remainingBalance,
        parseDate(row["Due Date"]),
        parseDate(row["Date Given"]),
        row.Location || null,
        row
      ]
    );
  }
}

async function mirrorInventory(rows) {
  for (const row of toObjects(rows)) {
    await pool.query(
      `insert into inventory_items
        (sheet_name, row_number, product, category, listed_amount, pawned_amount, sell_amount, profit, status, payload)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       on conflict (sheet_name, row_number) do update set
        product = excluded.product,
        category = excluded.category,
        listed_amount = excluded.listed_amount,
        pawned_amount = excluded.pawned_amount,
        sell_amount = excluded.sell_amount,
        profit = excluded.profit,
        status = excluded.status,
        payload = excluded.payload,
        updated_at = now()`,
      [
        "Company Owned Items",
        row.__rowNumber,
        row.Product || null,
        row.Category || null,
        parseNumber(row["List amount"]),
        parseNumber(row["Amount paid"]),
        parseNumber(row["Sell amount"]),
        parseNumber(row["Profit/loss"]),
        row["Listed on Market place"] || null,
        row
      ]
    );
  }
}

async function recordSyncJob(kind, payload, status) {
  if (!pool) return;
  await pool.query(
    `insert into sync_jobs (kind, status, payload, created_at, updated_at)
     values ($1, $2, $3, now(), now())`,
    [kind, status, payload]
  );
}

async function recordInventorySale(item) {
  if (!pool) return;
  await pool.query(
    `insert into inventory_sales
      (sheet_name, row_number, product, category, listed_amount, pawned_amount, expected_repayment, sell_amount, profit, sale_date, date_given, days_held, payload)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
     on conflict (sheet_name, row_number) do update set
      product = excluded.product,
      category = excluded.category,
      listed_amount = excluded.listed_amount,
      pawned_amount = excluded.pawned_amount,
      expected_repayment = excluded.expected_repayment,
      sell_amount = excluded.sell_amount,
      profit = excluded.profit,
      sale_date = excluded.sale_date,
      date_given = excluded.date_given,
      days_held = excluded.days_held,
      payload = excluded.payload,
      updated_at = now()`,
    [
      item.sheetName,
      item.rowNumber,
      item.product,
      item.category,
      Number(item.listedAmount || 0),
      Number(item.pawnedAmount || 0),
      Number(item.expectedRepayment || 0),
      Number(item.sellAmount || 0),
      Number(item.profit || 0),
      item.saleDate || null,
      item.dateGiven || null,
      item.daysHeld || null,
      item
    ]
  );
}

async function recordLoanPayment(metadata) {
  if (!pool || metadata?.type !== "loan_update" || !metadata.loan) return;
  const loan = metadata.loan;
  if (!Number(loan.paymentAmount || 0) && !loan.dueDate) return;
  if (Number(loan.paymentAmount || 0) > 0) {
    await pool.query(
      `insert into payments (sheet_name, row_number, client_name, amount, due_date, payload)
       values ($1,$2,$3,$4,$5,$6)`,
      [loan.sheetName, loan.rowNumber, loan.clientName, Number(loan.paymentAmount), loan.dueDate || null, loan]
    );
  }
  await pool.query(
    `update loans
     set amount_paid = amount_paid + $1,
         remaining_balance = greatest(total_payback - (amount_paid + $1), 0),
         due_date = coalesce($2, due_date),
         updated_at = now()
     where sheet_name = $3 and row_number = $4`,
    [Number(loan.paymentAmount || 0), loan.dueDate || null, loan.sheetName, loan.rowNumber]
  );
}

createServer(async (req, res) => {
  if (req.method === "OPTIONS") return sendJson(res, 200, { ok: true });
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname === "/api/health") {
      return sendJson(res, 200, {
        ok: true,
        googleSheets: Boolean(googleServiceAccountFile || googleServiceAccountJson),
        postgres: Boolean(pool)
      });
    }
    if (url.pathname === "/api/sheet-data") return sendJson(res, 200, { ok: true, data: await getSheetData() });
    if (url.pathname === "/api/sheet-batch-update" && req.method === "POST") {
      const payload = await readBody(req);
      await recordLoanPayment(payload.metadata || {});
      return sendJson(res, 200, { ok: true, result: await batchUpdate(payload.updates || [], payload.metadata || {}) });
    }
    if (url.pathname === "/api/inventory-sale" && req.method === "POST") {
      const payload = await readBody(req);
      await recordInventorySale(payload.item || {});
      return sendJson(res, 200, { ok: true, result: await batchUpdate(payload.updates || [], { type: "inventory_sale", item: payload.item }), sale: payload.item });
    }
    return sendJson(res, 404, { error: "Not found" });
  } catch (error) {
    await recordSyncJob("error", { message: error.message, stack: error.stack }, "failed").catch(() => {});
    return sendJson(res, 500, { error: error.message });
  }
}).listen(port, () => {
  console.log(`PawnTrack Flutter bridge running on http://127.0.0.1:${port}`);
});
