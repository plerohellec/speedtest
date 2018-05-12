require 'spec_helper'

module Speedtest
  describe Ring do
    before :each do
      @ring = Ring.new(3)
    end

    it 'should raise for size 0' do
      expect { Ring.new(0) }.to raise_error(ArgumentError)
    end

    it 'appends and pops elements' do
      @ring.append(0)
      expect(@ring.pop).to eq(0)
    end

    describe 'pop' do
      it 'returns nil when ring is empty' do
        expect(@ring.pop).to eq(nil)
      end

      it 'returns element FIFO' do
        @ring.append(0)
        @ring.append(1)
        @ring.append(2)
        expect(@ring.pop).to eq(0)
        expect(@ring.pop).to eq(1)
        expect(@ring.pop).to eq(2)
      end
    end

    describe 'append' do
      it 'raises when ring is full' do
        @ring.append(0)
        @ring.append(1)
        @ring.append(2)
        expect { @ring.append(3) }.to raise_error(FullRing)
      end

      it 'loops around the ring' do
        @ring.append(0)
        @ring.append(1)
        @ring.append(2)
        expect(@ring.pop).to eq(0)
        @ring.append(3)
        expect(@ring.pop).to eq(1)
        @ring.append(4)
        expect(@ring.pop).to eq(2)
        expect(@ring.pop).to eq(3)
        @ring.append(5)
        expect(@ring.pop).to eq(4)
        expect(@ring.pop).to eq(5)
        expect(@ring.pop).to eq(nil)
      end
    end
  end
end
