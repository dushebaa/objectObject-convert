FROM node:23-alpine

WORKDIR /app

COPY package.json .
COPY pnpm-lock.yaml .

RUN npm i -g pnpm
RUN pnpm install

COPY . .
RUN pnpm build

ENV PORT 4173
EXPOSE 4173

CMD [ "npm", "run", "preview:host" ]