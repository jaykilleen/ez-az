class LearnController < ApplicationController
  include RespectsStoreHours

  def show
    @channels   = LearningChannel.all
    @categories = LearningChannel.categories
  end
end
