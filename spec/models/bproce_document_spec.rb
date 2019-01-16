# frozen_string_literal: true

require 'rails_helper'

describe BproceDocument do
  context 'with associations' do
    it { is_expected.to belong_to(:bproce) }
    it { is_expected.to belong_to(:document) }
  end
end
