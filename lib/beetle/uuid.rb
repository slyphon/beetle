module Beetle
  # wrapper around MRI and JRuby implementations of a UUID generator
  # the MRI version uses UUID4R which generates a v1 (time-based) UUID,
  # the jruby version uses java.util.UUID which generates v4 (random) UUIDs
  module UUID
    def self.uuid
      if defined?(::JRUBY_VERSION)
        Java::JavaUtil::UUID.randomUUID.to_s
      else
        UUID4R.uuid(1)
      end
    end
  end
end

