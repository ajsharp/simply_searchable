module SimplySearchable
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    
    # ==== Attributes
    # 
    # <tt>:title</tt> - Used to populate the ss_title virtual attribute, which should be used on the search results page. Defaults to :title.
    # <tt>:summary</tt> - Used to populate the ss_summary virtual attribute. Defaults to :description.
    def simply_searchable(options = {})
      options[:title]   ||= :title
      options[:summary] ||= :description
      
      self.class_eval do
        class_inheritable_accessor :title_field, :summary_field, :ss_fields

        write_inheritable_attribute :title_field, options[:title]
        write_inheritable_attribute :summary_field, options[:summary]
        write_inheritable_attribute :ss_fields, []
      end
      
      init_fields(options)
      
      self.extend(SearchMethods)
      self.send(:include, InstanceMethods)
      # self.init_fields, options)
      init_fields(options)
    end
    
    # ================================================
    # Protected
    # ================================================
    protected
      # fields is a hash
      def init_fields(fields)
        if fields.is_a?(Hash)
          self.class_eval { write_inheritable_attribute(:ss_fields, fields.values.select { |val| !val.blank? }) }
        elsif fields.is_a?(Array)
          self.class_eval { write_inheritable_attribute(:ss_fields, fields.select { |val| !val.blank? }) }
        end
      end

      def add_fields(fields)
        current_fields = read_inheritable_attribute :ss_fields
        ss_fields = current_fields + fields.select { |field| !field.blank? }
        write_attribute(self.class.ss_fields, ss_fields)
      end
  end # end of ClassMethods
  
  
  module InstanceMethods
    def breadcrumbs
      "#{self.class.name} > "
    end
    
    def ss_summary
      self.send(self.class.read_inheritable_attribute :summary_field)
    end
    
    def ss_title
      self.send(self.class.read_inheritable_attribute :title_field)
    end
  end # end of InstanceMethods
  
  module SearchMethods
    # Search takes a hash of attributes
    # 
    # ==== Attributes
    # 
    # <tt>:terms</tt> - a string containing the search terms; if empty an empty string will be used
    # <tt>:additional_fields</tt> - an array of the database column names to add on to those specified in the call to simply_searchable
    # <tt>:fields</tt> - search only the fields defined here. This is useful if you do not want to search the fields you will use for title and summary
    # <tt>:conditions</tt> - any additional conditions other than the search conditions to be passed (i.e. "active = TRUE")
    def simple_search(terms, options = {})
      check_options(options)
      @fields = build_fields(options)
      @terms  = build_terms(terms)
      options.delete :fields
      
      options[:conditions] = build_conditions(options[:conditions])
      options[:limit] ||= nil
      options[:order] ||= nil

      with_scope :find => options do
        find(:all)
      end
    end

    # ================================================
    # Protected
    # ================================================
    protected
      def build_fields(options)
        if !options[:fields].nil?
          fields = self.class.init_fields(options[:fields])
        elsif !options[:additional_fields].nil?
          fields = self.class.add_fields(options[:additional_fields])
        end
        fields = fields.nil? ? read_inheritable_attribute(:ss_fields) : fields
        fields.collect { |field| field.to_s + " LIKE ?"}
      end

      def build_terms(terms)
        "%#{terms}%"
      end
      
      # Builds the conditions string and adds on any additional conditions
      # 
      # ==== Attributes
      # 
      # <tt>additional_conditions</tt> - A simple SQL condition string. WARNING: The additional conditions string should not contain user-submitted data. It should be simple string such as active = TRUE, or user_id IS NOT NULL.
      # 
      def build_conditions(additional_conditions = '')
        if !additional_conditions.blank?
          additional_conditions = " AND #{additional_conditions.strip}"
        end
        [@fields.join(" OR ") + "#{additional_conditions}"] + [@terms] * @fields.size
      end

    # ================================================
    # Private
    # ================================================
    private
      def check_options(options)
        if !options[:conditions].blank?
          raise ActiveRecord::StatementInvalid, "options[:conditions] must be a String" unless options[:conditions].is_a?(String)
        end
      end
  end # end of SearchMethods
end
