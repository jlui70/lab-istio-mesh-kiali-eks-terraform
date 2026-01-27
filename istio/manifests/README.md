# Manifestos Istio - Canary Deployment com Circuit Breaker

## 📁 Estrutura de Diretórios

```
istio/manifests/
├── 01-namespace/              # Namespace com sidecar injection
├── 02-microservices-v1/       # Microserviços versão 1
├── 03-istio-gateway/          # Gateway e VirtualService para acesso externo
├── 04-canary-deployment/      # Canary + Circuit Breaker
├── 05-circuit-breaker/        # Order Management com Circuit Breaker
└── 06-observability/          # Prometheus, Grafana, Kiali, Jaeger
```

---

## 🔧 04-canary-deployment/

### **Arquivos:**

**product-catalog-v2.yaml** (Original)
- Deploy básico do product-catalog v2
- VirtualService com split 80/20
- DestinationRule com subsets v1 e v2

**product-catalog-v2-with-circuit-breaker.yaml** (Novo - Com Circuit Breaker)
- Mesma configuração do arquivo original
- **+ Circuit Breaker configurado:**
  - `consecutive5xxErrors: 3` - Ejeta após 3 erros seguidos
  - `interval: 10s` - Janela de análise de 10 segundos
  - `baseEjectionTime: 30s` - Pod fica ejetado por 30 segundos
  - `maxEjectionPercent: 100` - Pode ejetar até 100% dos pods
  - `minHealthPercent: 0` - Permite ejetar todos se necessário

---

## 🎯 Como Funciona o Circuit Breaker

### **Cenário Normal (Sem Falhas):**
```
Cliente → [80% v1] → ✅ HTTP 200
        → [20% v2] → ✅ HTTP 200
```

### **Cenário com Falhas na v2:**
```
1. Cliente → v2 → ❌ HTTP 500 (erro 1)
2. Cliente → v2 → ❌ HTTP 500 (erro 2)
3. Cliente → v2 → ❌ HTTP 500 (erro 3)

🔥 Circuit Breaker ATIVA!

4. v2 é EJETADA do pool por 30 segundos
5. Cliente → [100% v1] → ✅ HTTP 200
```

### **Recuperação Automática:**
- Após 30 segundos, Istio tenta enviar tráfego de teste para v2
- Se v2 voltar a funcionar, ela é reincluída no pool
- Tráfego volta para 80/20

---

## 🚀 Como Testar

### **Opção 1: Script Automatizado**

```bash
# Na raiz do projeto
./test-circuit-breaker-simple.sh
```

### **Opção 2: Manual**

```bash
# 1. Aplicar configuração com circuit breaker
kubectl apply -f istio/manifests/04-canary-deployment/product-catalog-v2-with-circuit-breaker.yaml

# 2. Verificar DestinationRule
kubectl get destinationrule product-catalog -n ecommerce -o yaml

# 3. Gerar tráfego
ALB_URL=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
while true; do curl -s http://$ALB_URL/api/products >/dev/null; sleep 0.5; done

# 4. Em outro terminal, simular falha
kubectl scale deployment product-catalog-v2 -n ecommerce --replicas=0

# 5. Observar no Kiali (http://localhost:20001)
# - v2 fica vermelha
# - v2 é ejetada
# - 100% tráfego vai para v1
```

---

## 📊 Visualizar no Kiali

**URL:** http://localhost:20001

**Configuração:**
1. **Graph** → Namespace: **ecommerce**
2. **Display:**
   - ✅ Traffic Distribution
   - ✅ Traffic Animation
3. **Graph Type:** Versioned app graph
4. **Duration:** Last 1m
5. **Refresh:** Every 10s

**O que observar:**
- **Normal:** v1 e v2 verdes, tráfego 80/20
- **Com falha:** v2 vermelha ou sem tráfego
- **Circuit Breaker ativo:** Apenas v1 recebe tráfego

---

## 🛡️ Configuração do Circuit Breaker

```yaml
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100
    http:
      http1MaxPendingRequests: 10
      maxRequestsPerConnection: 10
  outlierDetection:
    consecutive5xxErrors: 3      # Ejeta após 3 erros HTTP 500 seguidos
    interval: 10s                # Janela de análise
    baseEjectionTime: 30s        # Tempo que fica ejetado
    maxEjectionPercent: 100      # Pode ejetar 100% dos pods
    minHealthPercent: 0          # Permite ejetar todos
```

---

## 💡 Boas Práticas

### **Production Settings:**

```yaml
outlierDetection:
  consecutive5xxErrors: 5       # Mais tolerante
  interval: 30s                 # Janela maior
  baseEjectionTime: 60s         # Mais tempo para recuperação
  maxEjectionPercent: 50        # Não ejeta mais que 50%
  minHealthPercent: 25          # Mantém pelo menos 25% saudável
```

### **Desenvolvimento/Teste:**

```yaml
outlierDetection:
  consecutive5xxErrors: 3       # Mais sensível
  interval: 10s                 # Resposta rápida
  baseEjectionTime: 30s         # Recuperação rápida
  maxEjectionPercent: 100       # Pode ejetar todos
  minHealthPercent: 0           # Para demonstrações
```

---

## 📚 Documentação Oficial

- [Istio Circuit Breaking](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
- [Outlier Detection](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/outlier)
- [DestinationRule Reference](https://istio.io/latest/docs/reference/config/networking/destination-rule/)
