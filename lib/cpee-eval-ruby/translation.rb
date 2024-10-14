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

require 'json'
require 'yaml'
require 'xml/smart'
require 'riddl/client'

module CPEE
  module EvalRuby
    module Translation

      class ParamArray < ::Array
        def value(index)
          tmp = find_all{|e| e['name'] == index}
          case tmp.length
            when 0; nil
            when 1; tmp[0]['data']
            else tmp
          end if tmp
        end
      end

      def self::simplify_structurized_result(result)
        if result && result.length == 1
          if result[0].has_key? 'mimetype'
            if result[0]['mimetype'] == 'application/json'
              result = JSON::parse(CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])) rescue nil
            elsif result[0]['mimetype'] == 'text/csv'
              result = CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])
            elsif result[0]['mimetype'] == 'text/yaml'
              result = YAML::load(CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])) rescue nil
            elsif result[0]['mimetype'] == 'application/xml' || result[0]['mimetype'] == 'text/xml'
              result = XML::Smart::string(CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])) rescue nil
            elsif result[0]['mimetype'] == 'text/plain'
              result = CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])
              if result.start_with?("<?xml version=")
                result = XML::Smart::string(result)
              else
                result = result.to_f if result == result.to_f.to_s
                result = result.to_i if result == result.to_i.to_s
              end
            elsif result[0]['mimetype'] == 'text/html'
              result = CPEE::EvalRuby::Translation::extract_base64(result[0]['data'])
              result = result.to_f if result == result.to_f.to_s
              result = result.to_i if result == result.to_i.to_s
            else
              result = result[0]
            end
          else
            result = result[0]['data']
          end
        else
          result = ParamArray[*result]
        end
        if result.is_a? String
          enc = CPEE::EvalRuby::Translation::detect_encoding(result)
          enc == 'OTHER' ? result : (result.encode('UTF-8',enc) rescue CPEE::EvalRuby::Translation::convert_to_base64(result))
        else
          result
        end
      end

      def self::simplify_result(result)
        if result.length == 1
          if result[0].is_a? Riddl::Parameter::Simple
            result = result[0].value
          elsif result[0].is_a? Riddl::Parameter::Complex
            if result[0].mimetype == 'application/json'
              result = JSON::parse(result[0].value.read) rescue nil
            elsif result[0].mimetype == 'text/csv'
              result = result[0].value.read
            elsif result[0].mimetype == 'text/yaml'
              result = YAML::load(result[0].value.read) rescue nil
            elsif result[0].mimetype == 'application/xml' || result[0].mimetype == 'text/xml'
              result = XML::Smart::string(result[0].value.read) rescue nil
            elsif result[0].mimetype == 'text/plain'
              result = result[0].value.read
              if result.start_with?("<?xml version=")
                result = XML::Smart::string(result)
              else
                result = result.to_f if result == result.to_f.to_s
                result = result.to_i if result == result.to_i.to_s
              end
            elsif result[0].mimetype == 'text/html'
              result = result[0].value.read
              result = result.to_f if result == result.to_f.to_s
              result = result.to_i if result == result.to_i.to_s
            else
              result = result[0]
            end
          end
        else
          result = Riddl::Parameter::Array[*result]
        end
        if result.is_a? String
          enc = CPEE::EvalRuby::Translation::detect_encoding(result)
          enc == 'OTHER' ? result : (result.encode('UTF-8',enc) rescue CPEE::EvalRuby::Translation::convert_to_base64(result))
        else
          result
        end
      end

      def self::detect_encoding(text)
        if text.is_a? String
          if text.valid_encoding? && text.encoding.name == 'UTF-8'
            'UTF-8'
          else
            res = CharlockHolmes::EncodingDetector.detect(text)
            if res.is_a?(Hash) && res[:type] == :text && res[:ruby_encoding] != "binary"
              res[:encoding]
            elsif res.is_a?(Hash) && res[:type] == :binary
              'BINARY'
            else
              'ISO-8859-1'
            end
          end
        else
          'OTHER'
        end
      end

      def self::convert_to_base64(text)
        ('data:' + MimeMagic.by_magic(text).type + ';base64,' + Base64::encode64(text)) rescue ('data:application/octet-stream;base64,' + Base64::encode64(text))
      end
      def self::extract_base64(text)
        if text.is_a?(String) && text.start_with?(/(data:[\w_\/-]+;base64,)/)
          Base64::decode64(text.delete_prefix $1)
        else  
          text
        end
      end

      def self::structurize_result(result)
        result.map do |r|
          if r.is_a? Riddl::Parameter::Simple
            { 'name' => r.name, 'data' => r.value }
          elsif r.is_a? Riddl::Parameter::Complex
            res = if r.mimetype == 'application/json'
              ttt = r.value.read
              enc = CPEE::EvalRuby::Translation::detect_encoding(ttt)
              enc == 'OTHER' ? ttt.inspect : (ttt.encode('UTF-8',enc) rescue CPEE::EvalRuby::Translation::convert_to_base64(ttt))
            elsif r.mimetype == 'text/csv'
              ttt = r.value.read
              enc = CPEE::EvalRuby::Translation::detect_encoding(ttt)
              enc == 'OTHER' ? ttt.inspect : (ttt.encode('UTF-8',enc) rescue CPEE::EvalRuby::Translation::convert_to_base64(ttt))
            elsif r.mimetype == 'text/plain' || r.mimetype == 'text/html'
              ttt = r.value.read
              ttt = ttt.to_f if ttt == ttt.to_f.to_s
              ttt = ttt.to_i if ttt == ttt.to_i.to_s
              enc = CPEE::EvalRuby::Translation::detect_encoding(ttt)
              enc == 'OTHER' ? ttt.inspect : (ttt.encode('UTF-8',enc) rescue CPEE::EvalRuby::Translation::convert_to_base64(ttt))
            else
              CPEE::EvalRuby::Translation::convert_to_base64(r.value.read)
            end

            tmp = {
              'name' => r.name == '' ? 'result' : r.name,
              'mimetype' => r.mimetype,
              'data' => res.to_s
            }
            r.value.rewind
            tmp
          end
        end
      end

    end
  end
end

