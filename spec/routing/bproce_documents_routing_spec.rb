require "spec_helper"

describe BproceDocumentsController do
  describe "routing -   resources :bproce_documents, :only => [:show]" do

    it "routes to #show" do
      get("/bproce_documents/1").should route_to("bproce_documents#show", id: "1")
    end

    it "routes /bproce_documents/1 to bproce-documents#show" do
        expect(get: "/bproce_documents/1").to route_to(
        controller: "bproce_documents",
        action: "show",
        id: "1"
        )
      end

    it "does not expose a list of bproce_documents" do
      expect(get: "/bproce_documents").to_not be_routable
    end

    it "routes to #edit" do
      get("/bproce_documents/1/edit").should route_to("bproce_documents#edit", :id => "1")
    end

    it "routes to #update" do
      put("/bproce_documents/1").should route_to("bproce_documents#update", :id => "1")
    end

  end
end
