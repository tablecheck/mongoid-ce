# frozen_string_literal: true

# A simplistic mock object to stand in for Rails, instead of adding an
# otherwise unnecessary dependency on Rails itself.

require 'ostruct'

module Rails
  extend self

  attr_accessor :env, :root, :logger, :application

  module Application
    extend self

    attr_accessor :config

    def eager_load!; end
  end
end

Rails.env = 'development'
Rails.root = Pathname.new('.')
Rails.logger = Logger.new($stdout)
Rails.application = Rails::Application

Rails.application.config = OpenStruct.new(
  paths: { 'app/models' => OpenStruct.new(expanded: ['app/models']) }
)
