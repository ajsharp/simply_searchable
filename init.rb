# require 'lib/simply_searchable'
ActiveRecord::Base.class_eval { include SimplySearchable }
