require 'rails_helper'

describe Api::GraphqlController, type: :request do
  describe 'approve_order mutation' do
    include_context 'GraphQL Client'
    let(:partner_id) { jwt_partner_ids.first }
    let(:user_id) { jwt_user_id }
    let(:credit_card_id) { 'cc-1' }
    let(:order) { Fabricate(:order, partner_id: partner_id, user_id: user_id) }

    let(:mutation) do
      <<-GRAPHQL
        mutation($input: ApproveOrderInput!) {
          approveOrder(input: $input) {
            order {
              id
              userId
              partnerId
              state
            }
            errors
          }
        }
      GRAPHQL
    end

    let(:approve_order_input) do
      {
        input: {
          id: order.id.to_s
        }
      }
    end
    context 'with user without permission to this partner' do
      let(:partner_id) { 'another-partner-id' }
      it 'returns permission error' do
        response = client.execute(mutation, approve_order_input)
        expect(response.data.approve_order.errors).to include 'Not permitted'
        expect(order.reload.state).to eq Order::PENDING
      end
    end

    context 'with order not in submitted state' do
      before do
        order.update_attributes! state: Order::PENDING
      end
      it 'returns error' do
        response = client.execute(mutation, approve_order_input)
        expect(response.data.approve_order.errors).to include 'Order cannot be approved'
        expect(order.reload.state).to eq Order::PENDING
      end
    end

    context 'with proper permission' do
      before do
        order.update_attributes! state: Order::SUBMITTED
      end
      it 'approves the order' do
        response = client.execute(mutation, approve_order_input)
        expect(response.data.approve_order.order.id).to eq order.id.to_s
        expect(response.data.approve_order.order.state).to eq Order::APPROVED
        expect(response.data.approve_order.errors).to match []
        expect(order.reload.state).to eq Order::APPROVED
      end
    end
  end
end
