(function() {
  window.addEventListener("load", function() {
    var clickListener = function(event) {
      console.log("click");
      var divId = event.target.getAttribute("data-id");
      var div = document.getElementById(divId);
      var forms = document.getElementsByClassName("payment_method_form");
      for (var i = forms.length - 1; i >= 0; i--) {
        var elem = forms[i];
        if (elem === div) {
          elem.className = "payment_method_form"
        } else {
          elem.className = "payment_method_form hidden"
        }
      };
    };

    var ccButton = document.getElementById("credit_card_radio_button");
    var ddButton = document.getElementById("direct_debit_radio_button");
    if (ccButton) {
      ccButton.addEventListener("click", clickListener);
    };
    if (ddButton) {
      ddButton.addEventListener("click", clickListener);
    }
  });
})();
