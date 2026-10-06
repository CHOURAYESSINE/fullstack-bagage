FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npx ng build public
FROM nginxinc/nginx-unprivileged:stable-alpine
COPY public/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/public/browser /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
