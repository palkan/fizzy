# typed: true

# @requires_ancestor: ActionView::Base
module HotkeysHelper
  # Pass in an array of chorded keys, e.g. ["ctrl", "shift", "J"]
  #: (Array[String]) -> String
  def hotkey_label(hotkey)
    hotkey.map do |key|
      if key == "ctrl" && platform.mac?
        "⌘"
      elsif key == "enter"
        platform.mac? ? "return" : "enter"
      else
        key
      end.capitalize
    end.join("+").gsub(/⌘\+/, "⌘")
  end
end
