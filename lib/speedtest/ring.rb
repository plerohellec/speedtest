module Speedtest
  class FullRing < StandardError; end

  class Ring
    def initialize(size)
      raise ArgumentError, 'size cannot be 0' if size == 0

      @size = size
      @arr = Array.new(size)
      @num_free = @size

      @append_pos = 0
      @pop_pos = 0
    end

    def append(elt)
      raise FullRing unless num_free > 0

      @arr[append_pos] = elt

      @num_free -= 1
      @append_pos += 1
    end

    def pop
      return nil unless num_busy > 0

      value = @arr[pop_pos]
      @arr[pop_pos] = nil

      @num_free += 1
      @pop_pos += 1

      return value
    end

    private

    def append_pos
      @append_pos % @size
    end

    def pop_pos
      @pop_pos % @size
    end

    def num_free
      @num_free
    end

    def num_busy
      @size - @num_free
    end
  end
end
