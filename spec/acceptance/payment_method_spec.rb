require_relative "./acceptance_spec_helper"

feature "Payment Method", "" do
  Steps "Some test" do
    Given "I have set up credit card data" do
      embedding_page = ClientPaydataTestPage.new
      embedding_page.load
      expect(embedding_page.client_paydata.payment_method.edit_form).to be_visible
      embedding_page.client_paydata.payment_method.credit_card_radio_button.click
      embedding_page.client_paydata.payment_method.update_to_credit_card({})
    end
  end
end
