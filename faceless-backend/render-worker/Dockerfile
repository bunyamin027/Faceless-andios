FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg curl python3 python3-pip pipx && \
    pipx install edge-tts && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY src/ ./src/
COPY fonts/ ./fonts/

EXPOSE 8080
CMD ["node", "src/server.js"]
