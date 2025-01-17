#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BASE_DIR="${SCRIPTDIR}/../../"

BOOKINFO_FILE="testdata/bookinfo/platform/kube/bookinfo.yaml"
GATEWAY_FILE="testdata/bookinfo/networking/bookinfo-gateway.yaml"
RULE_FILE="testdata/bookinfo/networking/destination-rule-all.yaml"

echo -n "namespace ? [bookinfo] "
read NAMESPACE

if [[ -z ${NAMESPACE} ]];then
  NAMESPACE=bookinfo
fi

echo "using NAMESPACE=${NAMESPACE}"

if [[ ${NAMESPACE} == "bookinfo" ]];then
  protos=( destinationrules virtualservices gateways )
  for proto in "${protos[@]}"; do
    for resource in $(oc get -n ${NAMESPACE} $proto | awk 'NR>1{print $1}'); do
      oc delete -n ${NAMESPACE} $proto $resource;
    done
  done
  #oc delete mixer-rule ratings-ratelimit
else
  oc delete -f ${GATEWAY_FILE} -n ${NAMESPACE}
  oc delete -f ${RULE_FILE} -n ${NAMESPACE}
fi

export OUTPUT=$(mktemp)
echo "Application cleanup may take up to one minute"
oc delete -n ${NAMESPACE} -f ${BOOKINFO_FILE} > ${OUTPUT} 2>&1
ret=$?
function cleanup() {
  rm -f ${OUTPUT}
}

trap cleanup EXIT

if [[ ${ret} -eq 0 ]];then
  cat ${OUTPUT}
else
  # ignore NotFound errors
  OUT2=$(grep -v NotFound ${OUTPUT})
  if [[ ! -z ${OUT2} ]];then
    cat ${OUTPUT}
    exit ${ret}
  fi
fi


if [[ ${NAMESPACE} == "bookinfo" ]];then
  set +e
  oc get pods -n ${NAMESPACE} | grep -viE 'Terminating|STATUS'
  while [ $? -eq 0 ]; do
	  sleep 3;
	  oc get pods -n ${NAMESPACE} | grep -viE 'Terminating|STATUS'
  done
  
fi

echo "Bookinfo Application cleanup successful"

