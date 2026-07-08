#!/bin/sh
# =============================================
# 远东工友 App — Let's Encrypt 初始化
# =============================================
# 使用前请确认:
#   1. DNS 已将 fsapp.fefacade.com 指向服务器 IP
#   2. 服务器 80 端口已开放并可达
#   3. 已修改下面的 EMAIL 为你的邮箱
# =============================================

set -e

DOMAIN="fsapp.fefacade.com"
EMAIL="your-email@example.com"

echo "========================================="
echo "  Let's Encrypt 证书初始化"
echo "  域名: ${DOMAIN}"
echo "========================================="

# 检查域名解析
echo ""
echo "[1/3] 检查域名 DNS 解析..."
RESOLVED_IP=$(dig +short "${DOMAIN}" 2>/dev/null || nslookup "${DOMAIN}" 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')
if [ -z "${RESOLVED_IP}" ]; then
    echo "  ✗ 无法解析域名 ${DOMAIN}，请先配置 DNS"
    exit 1
fi
echo "  ✓ 域名解析到: ${RESOLVED_IP}"

# 生成占位自签名证书（用于 Nginx 首次启动）
echo ""
echo "[2/3] 生成占位自签名证书..."
mkdir -p ../nginx/ssl
openssl req -x509 -nodes -days 90 -newkey rsa:2048 \
    -keyout ../nginx/ssl/privkey.pem \
    -out ../nginx/ssl/fullchain.pem \
    -subj "/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN}" 2>/dev/null || \
openssl req -x509 -nodes -days 90 -newkey rsa:2048 \
    -keyout ../nginx/ssl/privkey.pem \
    -out ../nginx/ssl/fullchain.pem \
    -subj "/CN=${DOMAIN}"
echo "  ✓ 自签名证书已生成（有效期 90 天）"

# 获取 Let's Encrypt 正式证书
echo ""
echo "[3/3] 获取 Let's Encrypt 正式证书..."
echo "  （这需要 80 端口可从公网访问）"
echo ""
echo "  请运行以下命令获取正式证书:"
echo ""
echo "  docker compose run --rm certbot certonly --webroot \\"
echo "    --webroot-path=/var/www/certbot \\"
echo "    -d ${DOMAIN} \\"
echo "    --email ${EMAIL} \\"
echo "    --agree-tos --no-eff-email"
echo ""
echo "  获取成功后重启 Nginx:"
echo "  docker compose restart nginx"
echo ""
echo "========================================="
echo "  初始化完成"
echo "========================================="
