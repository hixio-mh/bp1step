RSpec.describe 'Iresources', type: :request do
  describe 'GET /iresources' do
    it 'works! (now write some real specs)' do
      get iresources_path
      expect(response).to have_http_status(200)
    end
  end
end
