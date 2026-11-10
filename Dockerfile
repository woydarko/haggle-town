# Haggle Town backend + web dashboard in one service (Railway).
# Secrets come from the platform's environment variables, never from the image.
FROM node:24-slim

WORKDIR /app
COPY web/package.json web/package-lock.json web/
RUN cd web && npm ci
COPY server/package.json server/package-lock.json server/
RUN cd server && npm ci --omit=dev

COPY web web
RUN cd web && npm run build
COPY server server

ENV NODE_ENV=production \
    PORT=8080 \
    DB_PATH=/data/haggle.sqlite
WORKDIR /app/server
EXPOSE 8080
CMD ["node", "src/main.ts"]
