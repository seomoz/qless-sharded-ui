# Encoding: utf-8

ENV['RACK_ENV'] = 'test'
require 'spec_helper'
require 'yaml'
require 'qless'
require 'qless/sharded_ui'
require 'capybara/rspec'
require 'capybara/poltergeist'
require 'rack/test'
require 'pry'

Capybara.javascript_driver = :poltergeist

module Qless
  describe ShardedUI, :integration, type: :request do
    let(:client1) { clients[0] }
    let(:client2) { clients[1] }

    let(:q1) { client1.queues['testing'] }
    let(:q2) { client2.queues['testing'] }
    
    before(:all) do
      Capybara.app = Qless::ShardedUI.new([
        Qless::ShardedClient.new('qless01', clients[0], '/qless01'), 
        Qless::ShardedClient.new('qless02', clients[1], '/qless02')
      ])
    end

    after(:all) do
      Capybara.using_driver(:poltergeist) do
        Capybara.current_session.driver.quit
      end
    end

    it 'can search for tags across all shards', js: true do
      jid1 = q1.put(Qless::Job, {}, tags: ['foo'])
      jid2 = q2.put(Qless::Job, {}, tags: ['foo'])
      
      visit '/'
      search = find('#tag-search')
      search.set('foo')

      page.execute_script("$('.navbar-search').submit()")
      
      page.should have_content('qless01')
      page.should have_content('qless02')
      page.should have_content(jid1[0...9])
      page.should have_content(jid2[0...9])
    end
  end
end
