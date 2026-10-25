module Search::Stemmer
  # @rbs skip -- declared in sig/generated/inline.rbs
  extend self

  STEMMER = Mittens::Stemmer.new

  #: (String?) -> String?
  def stem(value)
    if value.present?
      value.gsub(/[^\w\s]/, " ").split(/\s+/).map { |word| STEMMER.stem(word.downcase) }.join(" ")
    else
      value
    end
  end
end
