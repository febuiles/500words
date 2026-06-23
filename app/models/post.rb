class Post < ApplicationRecord
  belongs_to :user

  # Cap content length: the 500-word goal is ~3KB, so 50KB comfortably clears
  # legitimate use while preventing oversized writes and the CPU/memory cost of
  # word-counting and re-rendering arbitrarily large bodies.
  MAX_CONTENT_LENGTH = 50_000

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }

  before_save :calculate_word_count

  private
  # TODO: improve this
  def calculate_word_count
    self.word_count = content.split.size
  end
end
