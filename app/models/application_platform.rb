class ApplicationPlatform < PlatformAgent
  #: () -> bool
  def ios?
    match? /iPhone|iPad/
  end

  #: () -> bool
  def android?
    match? /Android/
  end

  #: () -> bool
  def mac?
    match? /Macintosh/
  end

  #: () -> bool
  def chrome?
    user_agent.browser.match? /Chrome/
  end

  #: () -> bool
  def edge?
    user_agent.browser.match? /Edg/
  end

  #: () -> bool
  def firefox?
    user_agent.browser.match? /Firefox|FxiOS/
  end

  #: () -> bool
  def safari?
    user_agent.browser.match? /Safari/
  end

  #: () -> bool
  def mobile?
    ios? || android?
  end

  #: () -> bool
  def desktop?
    !mobile?
  end

  #: () -> bool
  def native?
    match? /Hotwire Native/
  end

  #: () -> bool
  def windows?
    operating_system == "Windows"
  end

  #: () -> Symbol?
  def bridge_name
    case
    when native? && android? then :android
    when native? && ios?     then :ios
    end
  end

  #: () -> String
  def bridge_components
    extract_list_from_native_user_agent("bridge-components")
  end

  #: () -> String
  def type
    if native? && android?
      "native android"
    elsif native? && ios?
      "native ios"
    elsif mobile?
      "mobile web"
    else
      "desktop web"
    end
  end

  #: () -> String?
  def operating_system
    case user_agent.platform
    when /Android/   then "Android"
    when /iPad/      then "iPad"
    when /iPhone/    then "iPhone"
    when /Macintosh/ then "macOS"
    when /Windows/   then "Windows"
    when /CrOS/      then "ChromeOS"
    else
      os =~ /Linux/ ? "Linux" : os
    end
  end

  private
    #: (String prefix) -> String
    def extract_list_from_native_user_agent(prefix)
      if native?
        user_agent.to_s.match(/#{Regexp.escape(prefix)}: \[(.*?)\]/) { |matches| matches[1] }.to_s
      else
        ""
      end
    end
end
