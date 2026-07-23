class Post < ApplicationRecord
  belongs_to :user

  # Cap content length: the 500-word goal is ~3KB, so 50KB comfortably clears
  # legitimate use while preventing oversized writes and the CPU/memory cost of
  # word-counting and re-rendering arbitrarily large bodies.
  MAX_CONTENT_LENGTH = 50_000
  MAX_TITLE_LENGTH = 120

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }
  validates :title, length: { maximum: MAX_TITLE_LENGTH }

  # A cleared title falls back to the default name below.
  normalizes :title, with: ->(title) { title.strip.presence }

  before_create :assign_number
  before_save :calculate_word_count

  # The name shown everywhere: the writer's own title, or the post's
  # per-user sequence number when they haven't picked one.
  def display_title
    title.presence || "Post #{number}"
  end

  private

  def assign_number
    self.number = (user.posts.maximum(:number) || 0) + 1
  end

  # TODO: improve this
  def calculate_word_count
    self.word_count = content.split.size
  end
end
