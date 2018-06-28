class ClientPaydataTestPage < SitePrism::Page
  set_url '/payments/payment_method/edit'
  section :client_paydata, ::ClientPaydataSection, "#client-paydata-control"
end
