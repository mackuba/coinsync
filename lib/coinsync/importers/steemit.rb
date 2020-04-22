require 'bigdecimal'
require 'json'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'

module CoinSync
  module Importers
    class Steemit < Base
      register_importer :steemit

      STEEM = CryptoCurrency.new('STEEM')
      SBD = CryptoCurrency.new('SBD')

      def initialize(config, params = {})
        super
        @username = params['username']
      end

      def can_build?
        false
      end

      def can_import?(type)
        @username && [:balances].include?(type)
      end

      def import_balances
        json = Request.get_json("https://steemit.com/@#{@username}.json")

        if !json['user']
          raise "Steemit importer: Invalid response: #{json}"
        end

        data = json['user']

        steem_balance = get_amount(data['balance'])
        steem_savings = get_amount(data['savings_balance'])
        sbd_balance = get_amount(data['sbd_balance'])
        sbd_savings = get_amount(data['savings_sbd_balance'])
        reward_balance = get_amount(data['reward_steem_balance'])
        reward_sbd = get_amount(data['reward_sbd_balance'])

        power = (get_amount(data['vesting_shares']) * steem_per_share).round(3, BigDecimal::ROUND_DOWN)

        [
          Balance.new(STEEM, available: steem_balance, locked: steem_savings + reward_balance + power),
          Balance.new(SBD, available: sbd_balance, locked: sbd_savings + reward_sbd)
        ]
      end

      private

      def get_amount(string)
        BigDecimal.new(string.split(' ').first)
      end

      def steem_per_share
        @steem_per_share = begin
          total_vesting_fund_steem = get_amount(globals['total_vesting_fund_steem'])
          total_vesting_shares = get_amount(globals['total_vesting_shares'])

          total_vesting_fund_steem / total_vesting_shares
        end
      end

      def globals
        @globals ||= get_globals
      end

      def get_globals
        json = Request.post_json("https://api.steemit.com") { |request|
          request.body = JSON.generate({
            "jsonrpc": "2.0",
            "method": "condenser_api.get_dynamic_global_properties",
            "params": [],
            "id": 1
          })
        }

        if !json['result']
          raise "Steemit importer: Invalid response: #{json}"
        end

        json['result']
      end
    end
  end
end
