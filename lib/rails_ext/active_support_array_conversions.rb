# typed: true

# Not `@requires_ancestor: Array`: Sorbet can't require a generic ancestor
module ChoiceSentenceArrayConversion
  #: () -> String
  def to_choice_sentence
    #: self as Array[untyped]
    to_sentence two_words_connector: " or ", last_word_connector: ", or "
  end
end

Array.include ChoiceSentenceArrayConversion
