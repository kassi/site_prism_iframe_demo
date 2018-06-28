# frozen_string_literal: true

##
# Client paydata section containing the client billing address and the payment method as subsections.
#
class ClientPaydataSection < SitePrism::Section
  class ClientPaymentMethodSection < SitePrism::Section
    element :show, ".payment-method-section .show-layer"
    element :edit_button, "a#edit_payment_method_button"
    element :edit_form, ".payment-method-section .edit-layer"

    element :credit_card_radio_button, "#credit_card_radio_button"

    # Heidelpay hCO form elements. Must be defined as iframe otherwise no access to fields!
    class CcIframe < SitePrism::Page
      element :cc_header, "h1"

      def update_to_credit_card(credit_card)
        # no updates in demo version, just checking content
        expect(cc_header).to include("Example Domain")
      end
    end

    iframe :cc_iframe, CcIframe, "#credit_card_data"

    def update_to_credit_card(credit_card)
      wait_for_cc_iframe
      cc_iframe do |iframe|
        iframe.update_to_credit_card(credit_card)
      end
    end
  end

  section :payment_method, ClientPaymentMethodSection, ".payment-method-section"
end
