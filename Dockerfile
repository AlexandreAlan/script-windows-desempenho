FROM nginx:alpine

COPY Otimizador-Total.ps1 Otimizador-Total.bat Otimizador-GUI.ps1 Otimizador-GUI.bat /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

LABEL org.opencontainers.image.title="Script Windows Desempenho"
LABEL org.opencontainers.image.description="Mirror auto-hospedado do Otimizador Total para Windows 10/11 (versao grafica e menu)"
LABEL org.opencontainers.image.source="https://github.com/AlexandreAlan/script-windows-desempenho"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="AlexandreAlan"
