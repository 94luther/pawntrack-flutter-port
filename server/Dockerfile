FROM node:22-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY googleSheetsFirestoreBridge.mjs ./
COPY googleSheetsPostgresBridge.mjs ./

ENV NODE_ENV=production
CMD ["npm", "start"]
