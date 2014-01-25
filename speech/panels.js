// Generated by CoffeeScript 1.6.3
(function() {
  $(document).ready(function() {
    var closeAll, openAll;
    openAll = function() {
      return $(".page_collapsible").collapsible("openAll");
    };
    closeAll = function() {
      return $(".page_collapsible").collapsible("closeAll");
    };
    hljs.tabReplace = "    ";
    hljs.initHighlightingOnLoad();
    $.fn.slideFadeToggle = function(speed, easing, callback) {
      return this.animate({
        opacity: "toggle",
        height: "toggle"
      }, speed, easing, callback);
    };
    $(".collapsible").collapsible({
      defaultOpen: "section1",
      cookieName: "nav",
      speed: "slow",
      animateOpen: function(elem, opts) {
        return elem.next().slideFadeToggle(opts.speed);
      },
      animateClose: function(elem, opts) {
        return elem.next().slideFadeToggle(opts.speed);
      },
      loadOpen: function(elem) {
        return elem.next().show();
      },
      loadClose: function(elem, opts) {
        return elem.next().hide();
      }
    });
    $(".page_collapsible").collapsible({
      defaultOpen: "body_section1",
      cookieName: "body2",
      speed: "slow",
      animateOpen: function(elem, opts) {
        return elem.next().slideFadeToggle(opts.speed);
      },
      animateClose: function(elem, opts) {
        return elem.next().slideFadeToggle(opts.speed);
      },
      loadOpen: function(elem) {
        return elem.next().show();
      },
      loadClose: function(elem, opts) {
        return elem.next().hide();
      }
    });
    $("#closeAll").click(function(event) {
      event.preventDefault();
      return closeAll();
    });
    return $("#openAll").click(function(event) {
      event.preventDefault();
      return openAll();
    });
  });

}).call(this);
