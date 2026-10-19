# Renders vendored Solar icons as inline SVG at server render time, so pages
# need no iconify-icon web component and make no runtime icon requests.
# Icon data: config/icons/seera_icons.json (Solar by 480 Design, CC BY 4.0).
module IconHelper
  # Same box as the old `iconify-icon { display: inline-block; vertical-align: middle; }`
  # rule, overriding Tailwind preflight's `svg { display: block }`.
  BASE_CLASS = "inline-block align-middle".freeze

  ICONS = JSON.parse(Rails.root.join("config/icons/seera_icons.json").read).fetch("icons").freeze

  class UnknownIconError < ArgumentError; end

  def seera_icon(name, width: 24, class: nil, **attrs)
    icon = ICONS[name.to_s]
    unless icon
      raise UnknownIconError, "Unknown icon: #{name}" unless Rails.env.production?

      return "".html_safe
    end

    tag.svg(
      icon["body"].html_safe, # vendored, trusted SVG markup
      xmlns: "http://www.w3.org/2000/svg",
      width: width,
      height: width,
      viewBox: "0 0 #{icon["width"]} #{icon["height"]}",
      class: [ BASE_CLASS, binding.local_variable_get(:class) ].compact.join(" "),
      "aria-hidden": "true",
      focusable: "false",
      **attrs
    )
  end
end
