import { createServer } from "node:http";
import { createSign, randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import Busboy from "busboy";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const __dirname = dirname(fileURLToPath(import.meta.url));
const config = await readConfig();
const port = Number(process.env.PORT || config.port || 8810);
const googleSheetId = process.env.GOOGLE_SHEET_ID || config.googleSheetId;
const googleServiceAccountFile = process.env.GOOGLE_SERVICE_ACCOUNT_FILE || config.googleServiceAccountFile;
const googleServiceAccountJson = process.env.GOOGLE_SERVICE_ACCOUNT_JSON || config.googleServiceAccountJson;
const firebaseServiceAccountFile = process.env.FIREBASE_SERVICE_ACCOUNT_FILE || config.firebaseServiceAccountFile || googleServiceAccountFile;
const firebaseServiceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON || config.firebaseServiceAccountJson || googleServiceAccountJson;
const firebaseAccount = await readServiceAccount(firebaseServiceAccountJson, firebaseServiceAccountFile);
const firebaseProjectId = process.env.FIREBASE_PROJECT_ID || config.firebaseProjectId || firebaseAccount.project_id;
const firestoreDatabaseId = process.env.FIRESTORE_DATABASE_ID || config.firestoreDatabaseId || "(default)";
const firebaseStorageBucket = process.env.FIREBASE_STORAGE_BUCKET || config.firebaseStorageBucket || `${firebaseProjectId}.firebasestorage.app`;
const app = getApps().length
  ? getApps()[0]
  : initializeApp({
      credential: cert(firebaseAccount),
      projectId: firebaseProjectId,
      storageBucket: firebaseStorageBucket
    });
const db = firestoreDatabaseId === "(default)" ? getFirestore(app) : getFirestore(app, firestoreDatabaseId);
const bucket = getStorage(app).bucket(firebaseStorageBucket);
let cachedToken = null;

const sheetRanges = ["'Company Owned Items'!A1:AE1000", "'OS Debts'!A1:AG999", "'Active Pawns'!A1:AG991", "'Damaged goods'!A1:Z1000"];
const sheetToPayloadKey = {
  "Company Owned Items": "companyOwnedItems",
  "OS Debts": "osDebts",
  "Active Pawns": "activePawns",
  "Damaged goods": "damagedGoods"
};

async function readConfig() {
  try {
    return JSON.parse(await readFile(join(__dirname, "googleSheets.config.json"), "utf8"));
  } catch {
    return {};
  }
}

async function readServiceAccount(json, file) {
  if (json) return JSON.parse(json);
  if (file) return JSON.parse(await readFile(file, "utf8"));
  throw new Error("Missing firebaseServiceAccountFile/firebaseServiceAccountJson or Google service account fallback.");
}

function sendJson(res, status, payload) {
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type"
  });
  res.end(JSON.stringify(cleanForJson(payload)));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => resolve(body ? JSON.parse(body) : {}));
    req.on("error", reject);
  });
}

function cleanForJson(value) {
  if (Array.isArray(value)) return value.map(cleanForJson);
  if (value && typeof value === "object") {
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    return Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined).map(([k, v]) => [k, cleanForJson(v)]));
  }
  return value;
}

function cleanForFirestore(value) {
  if (Array.isArray(value)) {
    return value
      .map(v => Array.isArray(v) ? { values: cleanForFirestore(v) } : cleanForFirestore(v))
      .filter(v => v !== undefined);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined).map(([k, v]) => [k, cleanForFirestore(v)]));
  }
  return value === undefined ? null : value;
}

function base64url(value) {
  return Buffer.from(value).toString("base64").replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function getGoogleToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60000) return cachedToken.token;
  const account = await readServiceAccount(googleServiceAccountJson, googleServiceAccountFile);
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

async function fetchGoogleSheetData() {
  const params = new URLSearchParams();
  sheetRanges.forEach(range => params.append("ranges", range));
  const data = await sheetsFetch(`/values:batchGet?${params}`);
  const values = Object.fromEntries((data.valueRanges || []).map(range => [range.range.split("!")[0].replaceAll("'", ""), range.values || []]));
  return {
    syncedAt: new Date().toISOString(),
    source: "Google Sheets: NEW ONE",
    companyOwnedItems: values["Company Owned Items"] || [],
    osDebts: values["OS Debts"] || [],
    activePawns: values["Active Pawns"] || [],
    damagedGoods: values["Damaged goods"] || []
  };
}

async function getFirestoreSheetData() {
  const snapshot = await db.collection("sheetSnapshots").doc("latest").get();
  if (snapshot.exists && snapshot.data()?.payloadJson) {
    return JSON.parse(snapshot.data().payloadJson);
  }
  if (snapshot.exists && snapshot.data()?.payload) {
    return snapshot.data().payload;
  }
  return importSheetsToFirestore("auto_import_on_empty");
}

async function importSheetsToFirestore(reason = "manual_import") {
  const job = await createSyncJob("import_sheets_to_firestore", { reason });
  try {
    const data = await fetchGoogleSheetData();
    await saveCanonicalData(data, { importReason: reason });
    await updateSyncJob(job, "synced", { importedAt: new Date().toISOString() });
    return data;
  } catch (error) {
    await updateSyncJob(job, "failed", { error: error.message });
    throw error;
  }
}

async function saveCanonicalData(data, metadata = {}) {
  const payload = { ...data, source: "Cloud Firestore: PawnTrack", syncedAt: new Date().toISOString() };
  await db.collection("sheetSnapshots").doc("latest").set(cleanForFirestore({
    source: payload.source,
    syncedAt: payload.syncedAt,
    payloadJson: JSON.stringify(payload),
    metadata,
    updatedAt: FieldValue.serverTimestamp()
  }), { merge: true });
  await mirrorLoans("Active Pawns", payload.activePawns || []);
  await mirrorLoans("OS Debts", payload.osDebts || []);
  await mirrorInventory(payload.companyOwnedItems || []);
  return payload;
}

async function firestoreFirstBatchUpdate(updates, metadata = {}) {
  const job = await createSyncJob("sheet_batch_update", { updates, metadata });
  const current = await getFirestoreSheetData();
  const next = structuredClone(current);
  for (const update of updates) applySheetUpdate(next, update);
  const saved = await saveCanonicalData(next, { updates, metadata });
  await recordOperationalEvent(metadata, updates);
  try {
    const result = await sheetsFetch("/values:batchUpdate", {
      method: "POST",
      body: JSON.stringify({ valueInputOption: "USER_ENTERED", data: updates.map(update => ({ range: update.range, values: update.values })) })
    });
    await updateSyncJob(job, "synced", { result });
    return { firestore: "synced", googleSheets: "synced", result, data: saved };
  } catch (error) {
    await updateSyncJob(job, "failed", { error: error.message });
    return { firestore: "synced", googleSheets: "failed", error: error.message, data: saved };
  }
}

function parseRange(range) {
  const match = String(range).match(/^'?([^']+)'?!([A-Z]+)(\d+)(?::([A-Z]+)(\d+))?$/i);
  if (!match) throw new Error(`Unsupported range: ${range}`);
  return {
    sheetName: match[1],
    startColumn: columnToIndex(match[2]),
    startRow: Number(match[3]),
    endColumn: match[4] ? columnToIndex(match[4]) : columnToIndex(match[2]),
    endRow: match[5] ? Number(match[5]) : Number(match[3])
  };
}

function columnToIndex(column) {
  return [...column.toUpperCase()].reduce((sum, char) => sum * 26 + char.charCodeAt(0) - 64, 0) - 1;
}

function applySheetUpdate(data, update) {
  const parsed = parseRange(update.range);
  const key = sheetToPayloadKey[parsed.sheetName];
  if (!key) return;
  data[key] ||= [];
  const values = update.values || [];
  for (let rowOffset = 0; rowOffset < values.length; rowOffset++) {
    const rowIndex = parsed.startRow - 1 + rowOffset;
    data[key][rowIndex] ||= [];
    const rowValues = values[rowOffset] || [];
    for (let colOffset = 0; colOffset < rowValues.length; colOffset++) {
      data[key][rowIndex][parsed.startColumn + colOffset] = rowValues[colOffset];
    }
  }
}

function toObjects(rows) {
  const [headers, ...body] = rows || [[]];
  return body
    .map((row, index) => ({ row, rowNumber: index + 2 }))
    .filter(entry => entry.row?.some(cell => cell !== null && cell !== undefined && String(cell).trim() !== ""))
    .filter(entry => String(entry.row[0] || "").trim().toLowerCase() !== "totals")
    .map(entry => ({ ...Object.fromEntries((headers || []).map((h, i) => [String(h || `Column ${i + 1}`).trim(), entry.row[i] ?? null])), __rowNumber: entry.rowNumber, __row: entry.row }));
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

function stableId(...parts) {
  return parts.filter(Boolean).join("-").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || randomUUID();
}

function customerIdFromLoan(row, fallback) {
  return stableId(row["Customer ID Number / Omang"] || row.Omang || row["Client Number"] || row["Phone Number"] || row["Client Name"], fallback);
}

function riskScoreForLoan(row, loanAmount, remainingBalance, overdueDays) {
  return Math.round((overdueDays > 0 ? Math.min(overdueDays * 1.5, 45) : 0) +
    (parseNumber(row["Amount Paid"]) > 0 && remainingBalance > 0 ? 12 : 0) +
    (overdueDays > 0 && remainingBalance > 0 ? 25 : 0) +
    (loanAmount >= 5000 ? 20 : loanAmount >= 2500 ? 12 : 6));
}

function riskBand(score) {
  if (score >= 70) return "High risk";
  if (score >= 40) return "Medium risk";
  return "Low risk";
}

async function mirrorLoans(sheetName, rows) {
  const batch = db.batch();
  for (const row of toObjects(rows)) {
    const loanAmount = parseNumber(row["Loan Amount"]);
    const interestAmount = parseNumber(row["Interest Amount"]);
    const totalPayback = parseNumber(row["Total Payback"]) || loanAmount + interestAmount;
    const amountPaid = parseNumber(row["Amount Paid"]);
    const dueDate = parseDate(row["Due Date"]);
    const remainingBalance = parseNumber(row["Remaining Balance"]) || Math.max(totalPayback - amountPaid, 0);
    const overdueDays = Math.max(Math.round(parseNumber(row["Days Overdue"])), dueDate ? daysBetween(new Date(), new Date(dueDate)) : 0);
    const riskScore = parseNumber(row["Borrower Risk Score"]) || riskScoreForLoan(row, loanAmount, remainingBalance, overdueDays);
    const loanId = stableId(sheetName, "row", row.__rowNumber);
    const customerId = customerIdFromLoan(row, `${sheetName}-${row.__rowNumber}`);
    const customerRef = db.collection("customers").doc(customerId);
    const loanRef = db.collection("loans").doc(loanId);
    const itemRef = db.collection("items").doc(stableId(loanId, "item"));
    batch.set(customerRef, cleanForFirestore({
      customerCode: customerId,
      fullName: row["Client Name"] || `Customer ${row.__rowNumber}`,
      omang: row["Customer ID Number / Omang"] || row.Omang || null,
      phoneNumber: row["Phone Number"] || row["Client Number"] || null,
      emergencyContact: row["Emergency Contact"] || null,
      addressArea: row["Address / Area"] || null,
      customerPhotoUrl: row["Customer Photo"] || null,
      idPhotoUrl: row["ID Photo"] || null,
      updatedAt: FieldValue.serverTimestamp()
    }), { merge: true });
    batch.set(loanRef, cleanForFirestore({
      sheetName,
      rowNumber: row.__rowNumber,
      customerId,
      clientName: row["Client Name"] || null,
      itemPawned: row["Item Pawned"] || row["Column 1"] || null,
      loanAmount,
      interestAmount,
      totalPayback,
      amountPaid,
      remainingBalance,
      dueDate,
      dateGiven: parseDate(row["Date Given"]),
      location: row.Location || row["Storage Location"] || null,
      extensionCount: parseNumber(row["Extension Count"]),
      daysOverdue: overdueDays,
      forfeitureDate: parseDate(row["Forfeiture Date"]),
      saleDate: parseDate(row["Sale Date"]),
      actualProfit: parseNumber(row["Actual Profit"]),
      riskScore,
      correctionReason: row["Correction Reason"] || null,
      payload: row,
      updatedAt: FieldValue.serverTimestamp()
    }), { merge: true });
    batch.set(itemRef, cleanForFirestore({
      customerId,
      loanId,
      product: row["Item Pawned"] || row["Column 1"] || null,
      category: row.Category || null,
      serialOrImei: row["Item Serial / IMEI"] || null,
      proofOfOwnership: row["Proof Of Ownership"] || null,
      itemPhotoUrls: row["Item Photos"] ? String(row["Item Photos"]).split(",").map(v => v.trim()).filter(Boolean) : [],
      testingChecklist: row["Testing Checklist"] || null,
      storageLocation: row["Storage Location"] || row.Location || null,
      status: remainingBalance > 0 ? "pawned" : "closed",
      updatedAt: FieldValue.serverTimestamp()
    }), { merge: true });
    batch.set(db.collection("riskScores").doc(loanId), cleanForFirestore({
      customerId,
      loanId,
      score: riskScore,
      band: riskBand(riskScore),
      reasons: { sheetName, rowNumber: row.__rowNumber, overdueDays, remainingBalance, loanAmount },
      calculatedAt: FieldValue.serverTimestamp()
    }), { merge: true });
  }
  await batch.commit();
}

async function mirrorInventory(rows) {
  const batch = db.batch();
  for (const row of toObjects(rows)) {
    const inventoryId = stableId("company-owned-row", row.__rowNumber);
    const sold = parseNumber(row["Sell amount"]);
    batch.set(db.collection("inventory").doc(inventoryId), cleanForFirestore({
      sheetName: "Company Owned Items",
      rowNumber: row.__rowNumber,
      product: row.Product || null,
      category: row.Category || null,
      damages: row.Damages || null,
      listedStatus: row["Listed on Market place"] || null,
      listDate: parseDate(row["List Date"]),
      listedAmount: parseNumber(row["List amount"]),
      pawnedAmount: parseNumber(row["Amount paid"]),
      sellAmount: sold,
      profit: parseNumber(row["Profit/loss"]),
      location: row.Location || null,
      saleDate: parseDate(row["Sale Date"]),
      dateGiven: parseDate(row["Date Given"]),
      expectedRepayment: parseNumber(row["Expected Repayment"]),
      daysHeld: parseNumber(row["Days Held"]),
      status: sold > 0 || /sold/i.test(String(row["Listed on Market place"] || "")) ? "sold" : "available",
      payload: row,
      updatedAt: FieldValue.serverTimestamp()
    }), { merge: true });
  }
  await batch.commit();
}

function daysBetween(left, right) {
  const a = Date.UTC(left.getFullYear(), left.getMonth(), left.getDate());
  const b = Date.UTC(right.getFullYear(), right.getMonth(), right.getDate());
  return Math.round((a - b) / 86400000);
}

async function createSyncJob(kind, payload) {
  const ref = db.collection("syncJobs").doc();
  await ref.set(cleanForFirestore({ kind, status: "pending", payload, attempts: 0, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }));
  return ref;
}

async function updateSyncJob(ref, status, patch = {}) {
  await ref.set(cleanForFirestore({ status, ...patch, updatedAt: FieldValue.serverTimestamp() }), { merge: true });
}

async function recordOperationalEvent(metadata, updates) {
  if (!metadata?.type) return;
  const auditRef = db.collection("auditLog").doc();
  await auditRef.set(cleanForFirestore({
    entityType: metadata.type,
    entityId: metadata.loan?.rowNumber || metadata.item?.rowNumber || metadata.customerName || null,
    action: metadata.type,
    correctionReason: metadata.loan?.correctionReason || metadata.correctionReason || null,
    afterPayload: { metadata, updates },
    createdAt: FieldValue.serverTimestamp()
  }));
  if (metadata.type === "loan_update" && metadata.loan) await recordLoanPayment(metadata.loan);
  if (metadata.type === "new_pawn") {
    await db.collection("voiceCommands").add(cleanForFirestore({
      transcript: `Create a new pawn for ${metadata.customerName || "customer"}`,
      parsedAction: "new_pawn",
      status: "applied",
      payload: metadata,
      createdAt: FieldValue.serverTimestamp()
    }));
  }
  if (metadata.type === "forfeiture" && metadata.loan) {
    await db.collection("auditLog").add(cleanForFirestore({
      entityType: "loan",
      entityId: `${metadata.loan.sheetName}:${metadata.loan.rowNumber}`,
      action: "forfeit_to_inventory",
      afterPayload: metadata,
      createdAt: FieldValue.serverTimestamp()
    }));
  }
}

async function recordLoanPayment(loan) {
  if (Number(loan.paymentAmount || 0) > 0) {
    await db.collection("repayments").add(cleanForFirestore({
      sheetName: loan.sheetName,
      rowNumber: loan.rowNumber,
      clientName: loan.clientName,
      amount: Number(loan.paymentAmount),
      dueDate: loan.dueDate || null,
      payload: loan,
      createdAt: FieldValue.serverTimestamp()
    }));
  }
}

async function recordInventorySale(item) {
  if (!item) return;
  const saleId = stableId(item.sheetName, "row", item.rowNumber, "sale");
  await db.collection("sales").doc(saleId).set(cleanForFirestore({
    sheetName: item.sheetName,
    rowNumber: item.rowNumber,
    product: item.product,
    category: item.category,
    listedAmount: Number(item.listedAmount || 0),
    pawnedAmount: Number(item.pawnedAmount || 0),
    expectedRepayment: Number(item.expectedRepayment || 0),
    sellAmount: Number(item.sellAmount || 0),
    profit: Number(item.profit || 0),
    saleDate: item.saleDate || null,
    dateGiven: item.dateGiven || null,
    daysHeld: item.daysHeld || null,
    payload: item,
    updatedAt: FieldValue.serverTimestamp()
  }), { merge: true });
}

async function parseMultipartUpload(req) {
  return new Promise((resolve, reject) => {
    const busboy = Busboy({ headers: req.headers });
    const fields = {};
    let upload = null;
    busboy.on("field", (name, value) => fields[name] = value);
    busboy.on("file", (name, file, info) => {
      const chunks = [];
      file.on("data", chunk => chunks.push(chunk));
      file.on("end", () => {
        upload = { fieldName: name, fileName: info.filename || `${randomUUID()}.bin`, mimeType: info.mimeType || "application/octet-stream", buffer: Buffer.concat(chunks) };
      });
    });
    busboy.on("error", reject);
    busboy.on("finish", () => upload ? resolve({ fields, upload }) : reject(new Error("Missing file field.")));
    req.pipe(busboy);
  });
}

function uploadPath(kind, fields) {
  const customerId = fields.customerId || "unassigned-customer";
  const itemId = fields.itemId || "unassigned-item";
  const fileId = fields.fileId || randomUUID();
  if (kind === "customer-photo") return `customers/${customerId}/customer-photo/${fileId}`;
  if (kind === "id-photo") return `customers/${customerId}/id-photo/${fileId}`;
  if (kind === "item-photo") return `items/${itemId}/photos/${fileId}`;
  if (kind === "proof-of-ownership") return `items/${itemId}/proof/${fileId}`;
  throw new Error(`Unsupported upload kind: ${kind}`);
}

async function handleUpload(req, kind) {
  const { fields, upload } = await parseMultipartUpload(req);
  const token = randomUUID();
  const path = `${uploadPath(kind, fields)}-${upload.fileName.replace(/[^a-zA-Z0-9._-]+/g, "-")}`;
  const file = bucket.file(path);
  await file.save(upload.buffer, {
    contentType: upload.mimeType,
    metadata: { metadata: { firebaseStorageDownloadTokens: token } }
  });
  const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
  await db.collection("storageUploads").add(cleanForFirestore({
    kind,
    bucket: bucket.name,
    path,
    url,
    fileName: upload.fileName,
    mimeType: upload.mimeType,
    customerId: fields.customerId || null,
    itemId: fields.itemId || null,
    createdAt: FieldValue.serverTimestamp()
  }));
  if (fields.customerId && (kind === "customer-photo" || kind === "id-photo")) {
    await db.collection("customers").doc(fields.customerId).set({
      [kind === "customer-photo" ? "customerPhotoUrl" : "idPhotoUrl"]: url,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  }
  if (fields.itemId && (kind === "item-photo" || kind === "proof-of-ownership")) {
    const field = kind === "item-photo" ? "itemPhotoUrls" : "proofOfOwnershipUrls";
    await db.collection("items").doc(fields.itemId).set({ [field]: FieldValue.arrayUnion(url), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  return { kind, bucket: bucket.name, path, url, fileName: upload.fileName, mimeType: upload.mimeType };
}

export async function handleApiRequest(req, res) {
  if (req.method === "OPTIONS") return sendJson(res, 200, { ok: true });
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname === "/api/health") {
      return sendJson(res, 200, {
        ok: true,
        googleSheets: Boolean(googleSheetId && (googleServiceAccountFile || googleServiceAccountJson)),
        firestore: true,
        storage: Boolean(firebaseStorageBucket),
        firebaseProjectId,
        firestoreDatabaseId
      });
    }
    if (url.pathname === "/api/import/sheets-to-firestore" && req.method === "POST") {
      return sendJson(res, 200, { ok: true, data: await importSheetsToFirestore("manual_import") });
    }
    if (url.pathname === "/api/sheet-data" && req.method === "GET") {
      return sendJson(res, 200, { ok: true, data: await getFirestoreSheetData() });
    }
    if (url.pathname === "/api/sheet-batch-update" && req.method === "POST") {
      const payload = await readBody(req);
      return sendJson(res, 200, { ok: true, result: await firestoreFirstBatchUpdate(payload.updates || [], payload.metadata || {}) });
    }
    if (url.pathname === "/api/inventory-sale" && req.method === "POST") {
      const payload = await readBody(req);
      await recordInventorySale(payload.item || {});
      return sendJson(res, 200, { ok: true, result: await firestoreFirstBatchUpdate(payload.updates || [], { type: "inventory_sale", item: payload.item }), sale: payload.item });
    }
    if (url.pathname.startsWith("/api/upload/") && req.method === "POST") {
      const kind = url.pathname.split("/").pop();
      return sendJson(res, 200, { ok: true, upload: await handleUpload(req, kind) });
    }
    return sendJson(res, 404, { error: "Not found" });
  } catch (error) {
    await db.collection("syncJobs").add(cleanForFirestore({
      kind: "error",
      status: "failed",
      payload: { message: error.message, stack: error.stack },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    })).catch(() => {});
    return sendJson(res, 500, { error: error.message });
  }
}

export function startApiServer(listenPort = port) {
  return createServer(handleApiRequest).listen(listenPort, () => {
    console.log(`PawnTrack Firestore bridge running on http://127.0.0.1:${listenPort}`);
    console.log(`Firestore project ${firebaseProjectId}, database ${firestoreDatabaseId}, bucket ${firebaseStorageBucket}`);
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startApiServer(port);
}

export const runtimeConfig = {
  firebaseProjectId,
  firestoreDatabaseId,
  firebaseStorageBucket,
  googleSheets: Boolean(googleSheetId && (googleServiceAccountFile || googleServiceAccountJson))
};
