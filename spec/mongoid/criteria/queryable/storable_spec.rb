# frozen_string_literal: true

require "spec_helper"

describe Mongoid::Criteria::Queryable::Storable do
  let(:query) do
    Mongoid::Query.new
  end

  shared_examples_for 'logical operator expressions' do
    context '$and operator' do
      context '$and to empty query' do
        let(:modified) do
          query.send(query_method, '$and', [{ 'foo' => 'bar' }])
        end

        it 'adds to top level' do
          expect(modified.selector).to eq({ '$and' => [{ 'foo' => 'bar' }] })
        end
      end

      context '$and to query with other keys' do
        let(:query) do
          Mongoid::Query.new.where(zoom: 'zoom')
        end

        let(:modified) do
          query.send(query_method, '$and', [{ 'foo' => 'bar' }])
        end

        it 'adds to top level' do
          expect(modified.selector).to eq({ 'zoom' => 'zoom',
                                            '$and' => [{ 'foo' => 'bar' }] })
        end
      end

      context '$and to query with $and' do
        let(:query) do
          Mongoid::Query.new.where('$and' => [{ zoom: 'zoom' }])
        end

        let(:modified) do
          query.send(query_method, '$and', [{ 'foo' => 'bar' }])
        end

        it 'adds to existing $and' do
          expect(modified.selector).to eq({
                                            '$and' => [{ 'zoom' => 'zoom' }, { 'foo' => 'bar' }]
                                          })
        end
      end

      context '$and to query with $and which already has the given key' do
        let(:query) do
          Mongoid::Query.new.where('$and' => [{ foo: 'zoom' }])
        end

        let(:modified) do
          query.send(query_method, '$and', [{ 'foo' => 'bar' }])
        end

        it 'adds to existing $and' do
          expect(modified.selector).to eq({
                                            '$and' => [{ 'foo' => 'zoom' }, { 'foo' => 'bar' }],
                                          })
        end
      end

      context '$and to query with $and onto query whose first one is not $and' do
        let(:query) do
          Mongoid::Query.new.where({ 'foo' => 'baz' }).where('$and' => [{ zoom: 'zoom' }])
        end

        let(:modified) do
          query.send(query_method, '$and', [{ 'foo' => 'bar' }])
        end

        it 'adds to existing $and' do
          expect(modified.selector).to eq({ '$and' => [{ 'zoom' => 'zoom' }, { 'foo' => 'bar' }], 'foo' => 'baz' })
        end
      end
    end

    context '$or operator' do
      context '$or to empty query' do
        let(:modified) do
          query.send(query_method, '$or', [{ 'foo' => 'bar' }])
        end

        it 'adds to top level' do
          expect(modified.selector).to eq({ '$or' => [{ 'foo' => 'bar' }] })
        end
      end

      context '$or to query with other keys' do
        let(:query) do
          Mongoid::Query.new.where(zoom: 'zoom')
        end

        let(:modified) do
          query.send(query_method, '$or', [{ 'foo' => 'bar' }])
        end

        it 'adds the new conditions' do
          expect(modified.selector).to eq({
                                            'zoom' => 'zoom',
                                            '$or' => ['foo' => 'bar'],
                                          })
        end
      end

      context '$or to query with $or' do
        let(:query) do
          Mongoid::Query.new.where('$or' => [{ zoom: 'zoom' }])
        end

        let(:modified) do
          query.send(query_method, '$or', [{ 'foo' => 'bar' }])
        end

        it 'adds to existing $or' do
          expect(modified.selector).to eq({
                                            '$or' => [{ 'zoom' => 'zoom' }, { 'foo' => 'bar' }]
                                          })
        end
      end
    end
  end

  describe '#add_field_expression' do
    context 'simple field and value write' do
      let(:modified) do
        query.add_field_expression('foo', 'bar')
      end

      it 'adds the condition' do
        expect(modified.selector).to eq({
                                          'foo' => 'bar'
                                        })
      end
    end

    context 'an operator write' do
      let(:modified) do
        query.add_field_expression('$eq', { 'foo' => 'bar' })
      end

      it 'is not allowed' do
        expect do
          modified
        end.to raise_error(ArgumentError, /Field cannot be an operator/)
      end
    end

    context 'when another field exists in destination' do
      let(:base) do
        query.add_field_expression('foo', 'bar')
      end

      let(:modified) do
        base.add_field_expression('zoom', 'zoom')
      end

      it 'adds the condition' do
        expect(modified.selector).to eq({
                                          'foo' => 'bar',
                                          'zoom' => 'zoom',
                                        })
      end
    end

    context 'when field being added already exists in destination' do
      let(:base) do
        query.add_field_expression('foo', 'bar')
      end

      let(:modified) do
        base.add_field_expression('foo', 'zoom')
      end

      it 'adds the new condition using $and' do
        expect(modified.selector).to eq({
                                          'foo' => 'bar',
                                          '$and' => ['foo' => 'zoom'],
                                        })
      end
    end
  end

  describe '#add_operator_expression' do
    let(:query_method) { :add_operator_expression }

    it_behaves_like 'logical operator expressions'
  end

  describe '#add_logical_operator_expression' do
    let(:query_method) { :add_logical_operator_expression }

    it_behaves_like 'logical operator expressions'
  end
end
