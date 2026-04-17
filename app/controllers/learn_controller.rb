class LearnController < ApplicationController
  def show
    @channels   = LearningChannel.all
    @categories = LearningChannel.categories
  end
end
