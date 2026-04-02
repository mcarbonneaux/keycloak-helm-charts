#!/bin/bash
# Copyright 2026 Mathieu CARBONNEAUX
# SPDX-License-Identifier: APACHE-2.0

# Script pour configurer TLS sur Keycloak avec cert-manager
# Usage: ./setup-tls.sh [domain] [issuer-name]

set -e

# Configuration
DOMAIN="${1:-keycloak.example.com}"
ISSUER_NAME="${2:-letsencrypt-prod}"
NAMESPACE="keycloak"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔒 Configuration TLS pour Keycloak${NC}"
echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}Issuer: ${ISSUER_NAME}${NC}"
echo ""

# Vérifier cert-manager
echo -e "${YELLOW}Vérification de cert-manager...${NC}"
if ! kubectl get crd certificates.cert-manager.io &> /dev/null; then
    echo -e "${YELLOW}⚠ cert-manager n'est pas installé. Installation...${NC}"

    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.14.0 \
        --set installCRDs=true \
        --wait

    echo -e "${GREEN}✓ cert-manager installé${NC}"
else
    echo -e "${GREEN}✓ cert-manager déjà installé${NC}"
fi

# Créer le namespace si nécessaire
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    kubectl create namespace ${NAMESPACE}
    echo -e "${GREEN}✓ Namespace ${NAMESPACE} créé${NC}"
fi

# Créer/Vérifier le ClusterIssuer
echo ""
echo -e "${YELLOW}Configuration du ClusterIssuer...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${ISSUER_NAME}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN}
    privateKeySecretRef:
      name: ${ISSUER_NAME}-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo -e "${GREEN}✓ ClusterIssuer configuré${NC}"

# Créer le Certificate
echo ""
echo -e "${YELLOW}Création du Certificate...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak-tls
  namespace: ${NAMESPACE}
spec:
  secretName: keycloak-tls
  duration: 2160h
  renewBefore: 720h

  subject:
    organizations:
      - "Keycloak"

  dnsNames:
    - ${DOMAIN}

  issuerRef:
    name: ${ISSUER_NAME}
    kind: ClusterIssuer
    group: cert-manager.io

  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always
EOF

echo -e "${GREEN}✓ Certificate créé${NC}"

# Attendre que le certificat soit prêt
echo ""
echo -e "${YELLOW}Attente de l'émission du certificat (peut prendre quelques minutes)...${NC}"

if kubectl wait --for=condition=Ready certificate/keycloak-tls -n ${NAMESPACE} --timeout=300s; then
    echo -e "${GREEN}✓ Certificat émis avec succès!${NC}"

    # Afficher les détails
    echo ""
    echo -e "${BLUE}📋 Détails du certificat:${NC}"
    kubectl get secret keycloak-tls -n ${NAMESPACE} -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -A 2 "Subject:"
    kubectl get secret keycloak-tls -n ${NAMESPACE} -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
else
    echo -e "${YELLOW}⚠ Le certificat n'est pas encore prêt${NC}"
    echo -e "${YELLOW}Vérifiez le statut avec:${NC}"
    echo "  kubectl describe certificate keycloak-tls -n ${NAMESPACE}"
    echo "  kubectl get challenges -n ${NAMESPACE}"
fi

# Afficher les instructions
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Configuration TLS terminée!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Le certificat TLS est maintenant disponible dans le secret: keycloak-tls"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo ""
echo "1. Vérifier le certificat:"
echo "   kubectl get certificate -n ${NAMESPACE}"
echo "   kubectl describe certificate keycloak-tls -n ${NAMESPACE}"
echo ""
echo "2. Configurer votre Gateway pour utiliser le certificat:"
echo "   Référencez le secret 'keycloak-tls' dans votre Gateway"
echo ""
echo "3. Tester l'accès HTTPS:"
echo "   curl -v https://${DOMAIN}"
echo ""
echo "4. Le certificat sera automatiquement renouvelé 30 jours avant expiration"
echo ""
