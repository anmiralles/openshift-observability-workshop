#!/bin/bash

NC='\033[0m'          # Text Reset
BGreen='\033[1;32m'   # Green
BYellow='\033[1;33m'  # Yellow
BBlue='\033[1;34m'    # Blue

# this env will be used in traffic generator
export INGRESSHOST=$(oc get route istio-ingressgateway -n istio-ingress -o=jsonpath='{.spec.host}')
KIALI_HOST=$(oc get route kiali -n istio-system -o=jsonpath='{.spec.host}')

echo "${BYellow}[optional] Installing bookinfo traffic generator...${NC}"
cat ./traffic-generator-configmap.yaml | ROUTE="http://${INGRESSHOST}/productpage" envsubst | oc -n bookinfo apply -f -
oc apply -f ./traffic-generator.yaml -n bookinfo

echo "${BYellow}====================================================================================================${NC}"
echo "Ingress route for bookinfo is: \033[1;34mhttp://${INGRESSHOST}/productpage\033[0m"
echo "To test RestAPI: \033[1;34msh ./scripts/test-api.sh\033[0m"
echo "Kiali route is: \033[1;34mhttps://${KIALI_HOST}\033[0m"
echo "${BYellow}====================================================================================================${NC}"
