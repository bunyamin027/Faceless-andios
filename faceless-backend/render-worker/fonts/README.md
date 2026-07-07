# Fonts Directory

Place `Inter-Bold.ttf` here before building the Docker image.

Download from: https://fonts.google.com/specimen/Inter

```bash
# Quick download via curl
curl -sL "https://fonts.google.com/download?family=Inter" -o inter.zip
unzip inter.zip -d inter_font
cp inter_font/static/Inter-Bold.ttf ./Inter-Bold.ttf
rm -rf inter.zip inter_font
```
