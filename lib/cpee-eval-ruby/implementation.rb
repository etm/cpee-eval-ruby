# This file is part of CPEE-EVAL-RUBY.
#
# CPEE-EVAL-RUBY is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# CPEE-EVAL-RUBY is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
# for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with CPEE-EVAL-RUBY (file LICENSE in the main directory).  If not,
# see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'cpee/value_helper'
require 'xml/smart'
require 'riddl/server'
require 'securerandom'
require 'base64'
require 'uri'
require 'redis'
require 'json'
require 'weel'
require 'charlock_holmes'
require 'timeout'
require_relative 'translation'

module CPEE
  module EvalRuby

    SERVER = File.expand_path(File.join(__dir__,'implementation.xml'))

    class DoIt < Riddl::Implementation #{{{
      def exec(__struct,__code,result=nil,headers=nil)
        __ret = {}
        __cat = catch WEEL::Signal::Again do
          Timeout.timeout(7) do
            __ret[:res] = JSON::generate(__struct.instance_eval(__code))
          end
          WEEL::Signal::Proceed
        end
        if __cat.nil? || __cat == WEEL::Signal::Again
          __ret[:signal] << 'Signal::Again'
        end
      rescue Timeout::Error
        __ret[:signal] = 'Signal::Error'
        __ret[:signal_text] = 'Your code took longer than 7 seconds'
      rescue WEEL::Signal::Again
        __ret[:signal] = 'Signal::Again'
      rescue  WEEL::Signal::Error => err
        __ret[:signal] = 'Signal::Error'
        __ret[:signal_text] = (err.backtrace ? err.backtrace[0].gsub(/([\w -_]+):(\d+):in.*/,'\\1, Line \2: ') : '') + err.message
      rescue WEEL::Signal::Stop
        __ret[:signal] = 'Signal::Stop'
      rescue SyntaxError => err
        __ret[:signal] = 'Signal::SyntaxError'
        __ret[:signal_text] = err.message
      rescue => err
        __ret[:signal] = 'Signal::Error'
        __ret[:signal_text] = (err.backtrace ? err.backtrace[0].gsub(/([\w -_]+):(\d+):in.*/,'\\1, Line \2: ') : '') + err.message
      ensure
        return __ret
      end

      def response
        mode = @a[0]
        code = @p.shift.value
        dataelements = JSON::parse(@p.shift.value.read)
        local = nil
        local = JSON::parse(@p.shift.value.read) if @p[0].name == 'local'
        endpoints = JSON::parse(@p.shift.value.read)
        additional = JSON::parse(@p.shift.value.read)
        status = JSON::parse(@p.shift.value.read) if @p.any? && @p[0].name == 'status'
        status = WEEL::Status.new(status['id'],status['message']) if status
        call_result = JSON::parse(@p.shift.value.read) if @p.any? && @p[0].name == 'call_result'
        call_headers = JSON::parse(@p.shift.value.read) if @p.any? && @p[0].name == 'call_headers'

        local = local[0] if local && local.is_a?(Array)

        # symbolize keys, because JSON
        dataelements.transform_keys!{|k| k.to_sym}
        local.transform_keys!{|k| k.to_sym} if local
        endpoints.transform_keys!{|k| k.to_sym}
        additional.transform_keys!{|k| k.to_sym}
        additional.each_value do |v|
          v.transform_keys!{|k| k.to_sym}
        end

        if status || call_result || call_headers
          struct = WEEL::ManipulateStructure.new(dataelements,endpoints,status,local,additional)
          execresult = exec struct, code, CPEE::EvalRuby::Translation::simplify_structurized_result(call_result), call_headers

          send = []
          send << Riddl::Parameter::Complex.new('result','application/json',execresult[:res] || '')
          if execresult[:signal]
            send << Riddl::Parameter::Simple.new('signal',execresult[:signal])
            send << Riddl::Parameter::Simple.new('signal_text',execresult[:signal_text] || '')
            @status = 555
            return send
          end

          res = {}
          struct.changed_data.each do |e|
            res[e] = struct.data[e]
          end
          if res.any?
            send << Riddl::Parameter::Complex.new('dataelements','application/json',JSON::generate(dataelements)) if mode == :full
            send << Riddl::Parameter::Complex.new('changed_dataelements','application/json',JSON::generate(res))
          end
          res = {}
          struct.changed_endpoints.each do |e|
            res[e] = struct.endpoints[e]
          end
          if res.any?
            send << Riddl::Parameter::Complex.new('endpoints','application/json',JSON::generate(endpoints)) if mode == :full
            send << Riddl::Parameter::Complex.new('changed_endpoints','application/json',JSON::generate(res))
          end
          send << Riddl::Parameter::Complex.new('changed_status','application/json',JSON::generate(status)) if struct.changed_status
          send
        else
          struct = WEEL::ReadStructure.new(dataelements,endpoints,local,additional)
          execresult = exec struct, code
          send = []
          send << Riddl::Parameter::Complex.new('result','application/json',execresult[:res] || '')
          if execresult[:signal]
            send << Riddl::Parameter::Simple.new('signal',execresult[:signal])
            send << Riddl::Parameter::Simple.new('signal_text',execresult[:signal_text] || '')
            @status = 555
          end
          send
        end
      end
    end #}}}
    class Structurize < Riddl::Implementation #{{{
      def response
        Riddl::Parameter::Complex.new('structurized','application/json',JSON::generate(CPEE::EvalRuby::Translation::structurize_result(@p)))
      end
    end #}}}

    def self::implementation(opts)
      Proc.new do
        on resource do
          on resource 'exec' do
            run DoIt, :small if put 'exec'
          end
          on resource 'exec-full' do
            run DoIt, :full if put 'exec'
          end
          on resource 'structurize' do
            run Structurize if put
          end
        end
      end
    end

  end
end
