# data validation function
# Usage: validate_data

validate_data() {
   frictionless validate datapackage.yaml --yaml > frictionless_report_tmp.yaml
   frictionless_validity=$(< frictionless_report_tmp.yaml yq '.valid')
   if [ "$frictionless_validity" == "true" ]; then
      echo "✅ Il datapackage è valido!"
      rm frictionless_report_tmp.yaml
   else
      echo "❌ Il datapackage non è valido!"
      cat frictionless_report_tmp.yaml
      rm frictionless_report_tmp.yaml
      exit 1
      # esci e non committare nuovi dati
   fi
}