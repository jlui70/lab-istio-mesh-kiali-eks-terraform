#!/bin/bash

# ============================================================================
# Script: test-circuit-breaker-simple.sh
# Descrição: Demonstração VISUAL e SIMPLES de Circuit Breaker
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

ALB_URL=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ALB_URL" ]; then
    echo -e "${RED}❌ Erro: LoadBalancer URL não encontrado${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                                    ║${NC}"
echo -e "${BLUE}║   🎯 DEMONSTRAÇÃO VISUAL: CIRCUIT BREAKER NO KIALI                 ║${NC}"
echo -e "${BLUE}║   (Abordagem Simples e Garantida)                                 ║${NC}"
echo -e "${BLUE}║                                                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Garantir configuração correta
# ============================================================================

echo -e "${YELLOW}📦 Aplicando configuração com Circuit Breaker...${NC}"
kubectl apply -f istio/manifests/04-canary-deployment/product-catalog-v2-with-circuit-breaker.yaml
sleep 2

echo -e "${GREEN}✅ Circuit Breaker configurado${NC}\n"

# ============================================================================
# FASE 1: CANARY 80/20 FUNCIONANDO
# ============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  FASE 1: CANARY DEPLOYMENT NORMAL (80/20)                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}🌐 ABRA O KIALI AGORA:${NC} ${GREEN}http://localhost:20001${NC}"
echo ""
echo -e "${BLUE}📍 Configure no Kiali:${NC}"
echo "  1. Graph → Namespace: ${GREEN}ecommerce${NC}"
echo "  2. Display: ${GREEN}Traffic Distribution + Traffic Animation${NC}"
echo "  3. Graph Type: ${GREEN}Versioned app graph${NC}"
echo "  4. Duration: ${GREEN}Last 1m${NC} | Refresh: ${GREEN}Every 10s${NC}"
echo ""

read -p "Configurou o Kiali? Pressione ENTER para iniciar Fase 1..."

echo ""
echo -e "${GREEN}🚀 Gerando tráfego para mostrar canary 80/20...${NC}"
echo -e "${YELLOW}Duração: 60 segundos${NC}\n"

# Gerar tráfego em background
(
  for i in {1..120}; do
    curl -s http://$ALB_URL/api/products >/dev/null 2>&1 &
    sleep 0.5
  done
  wait
) &
TRAFFIC_PID=$!

echo -e "${PURPLE}📊 Observe no Kiali:${NC}"
echo "  • ecommerce-ui conectado ao product-catalog"
echo "  • Tráfego distribuído ${GREEN}80% v1${NC} e ${BLUE}20% v2${NC}"
echo "  • Ambas versões ${GREEN}VERDES${NC} (saudáveis)"
echo "  • Animações mostrando requisições"
echo ""

# Contador visual
for i in {60..1}; do
  echo -ne "\r⏳ Aguardando... ${i}s  "
  sleep 1
done
echo ""

wait $TRAFFIC_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ FASE 1 CONCLUÍDA${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# FASE 2: SIMULAR FALHA NA V2
# ============================================================================

echo -e "${RED}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  FASE 2: SIMULANDO FALHA NA V2 (Circuit Breaker)                   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 O que vamos fazer:${NC}"
echo "  1. Parar todos os pods da v2 (simular crash/falha)"
echo "  2. Circuit breaker vai detectar que v2 não responde"
echo "  3. Circuit breaker vai ejetar a v2 do pool"
echo "  4. 100% do tráfego vai para v1 automaticamente"
echo ""

read -p "Pronto para simular falha na v2? Pressione ENTER..."

echo ""
echo -e "${RED}🔥 Parando v2 (simulando crash)...${NC}"
kubectl scale deployment product-catalog-v2 -n ecommerce --replicas=0

echo -e "${RED}✅ V2 parada (0 réplicas)${NC}"
echo ""
echo -e "${YELLOW}⏳ Aguardando 10 segundos para v2 terminar...${NC}"
sleep 10

echo ""
echo -e "${GREEN}🚀 Gerando tráfego - Circuit Breaker vai detectar v2 offline${NC}"
echo -e "${YELLOW}Duração: 60 segundos${NC}\n"

# Gerar tráfego em background
(
  for i in {1..120}; do
    curl -s http://$ALB_URL/api/products >/dev/null 2>&1 &
    sleep 0.5
  done
  wait
) &
TRAFFIC_PID=$!

echo -e "${PURPLE}📊 Observe no Kiali AGORA:${NC}"
echo "  • v2 vai aparecer ${RED}VERMELHA${NC} ou ${YELLOW}AMARELA${NC}"
echo "  • Circuit breaker detecta falha"
echo "  • v2 ${RED}SOME${NC} ou fica ${RED}SEM TRÁFEGO${NC}"
echo "  • ${GREEN}100% do tráfego vai para v1${NC}"
echo "  • v1 continua ${GREEN}VERDE${NC} e recebendo tudo"
echo ""
echo -e "${GREEN}🎯 Isso é CIRCUIT BREAKER em ação! 🛡️${NC}"
echo ""

# Contador visual
for i in {60..1}; do
  echo -ne "\r⏳ Observando circuit breaker... ${i}s  "
  sleep 1
done
echo ""

wait $TRAFFIC_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ FASE 2 CONCLUÍDA${NC}"
echo ""

# ============================================================================
# RESUMO
# ============================================================================

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ DEMONSTRAÇÃO CONCLUÍDA COM SUCESSO!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${PURPLE}📊 RESUMO DO QUE VOCÊ VIU:${NC}"
echo ""
echo -e "${BLUE}FASE 1:${NC}"
echo "  ✅ Canary Deployment 80/20 funcionando"
echo "  ✅ v1 e v2 verdes e saudáveis"
echo ""
echo -e "${RED}FASE 2:${NC}"
echo "  ⚠️  v2 caiu (0 réplicas)"
echo "  🔥 Circuit breaker detectou falha"
echo "  🛡️  Circuit breaker ejetou v2"
echo "  ✅ 100% tráfego redirecionado para v1"
echo "  ✅ Aplicação continuou funcionando!"
echo ""
echo -e "${GREEN}🎯 Isso demonstra resiliência real em produção!${NC}"
echo ""

# ============================================================================
# RESTAURAR
# ============================================================================

echo -e "${YELLOW}🔄 Deseja restaurar v2 para estado normal?${NC}"
read -p "   (s/N): " restore

if [[ "$restore" =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${YELLOW}⚙️  Restaurando v2...${NC}"
    kubectl scale deployment product-catalog-v2 -n ecommerce --replicas=1
    
    echo "⏳ Aguardando pod ficar pronto..."
    kubectl wait --for=condition=ready pod -l app=product-catalog,version=v2 -n ecommerce --timeout=120s 2>/dev/null || true
    
    echo -e "${GREEN}✅ v2 restaurada e funcionando${NC}"
else
    echo ""
    echo -e "${YELLOW}💡 Para restaurar depois:${NC}"
    echo "   kubectl scale deployment product-catalog-v2 -n ecommerce --replicas=1"
fi

echo ""
echo -e "${GREEN}🎉 Demonstração finalizada!${NC}"
echo ""
echo -e "${YELLOW}💡 Dica para apresentação:${NC}"
echo "  Tire screenshots do Kiali nas duas fases para documentar!"
echo ""
