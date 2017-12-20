package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor

class FJsonDumpReader {
    @Inject private extension FrancaGeneratorExtensions

    def generateDumpReader(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <fstream>

        #include <«fInterface.serrializationHeaderPath»>

        struct SCall
        {
            std::string m_name;
            std::fstream::pos_type m_pos;
        };

        static const std::string s_time_key = "\"time\"";
        static const std::string s_name_key = "\"name\"";

        class JsonDumpReader
        {
        public:
            JsonDumpReader(const std::string& file_name);
            const std::vector<int64_t>& getTimestamps() const;
            const std::map<std::string, std::vector<std::size_t>>& getGropedTimestamps() const;

            void jump(std::size_t ts_id);
            const std::string& getRecordName(std::size_t ts_id);

            template<class T>
            void readItem(const std::string& tag, T& res);

        private:
            bool readKey(const std::string& src, const std::string& key, std::string& val);
            bool findBracket(const std::string& src, bool is_begin);

            std::ifstream m_file;

            std::vector<SCall> m_calls;
            std::vector<int64_t> m_timestamps;
            std::map<std::string, std::vector<std::size_t>> m_grouped_timestamps;

            boost::property_tree::ptree m_curr_pt;
        };

        template<class T>
        void JsonDumpReader::readItem(const std::string& tag, T& res) {
            boost::property_tree::ptree tmp_pt = m_curr_pt.get_child(tag);
            DataSerializer::readFromPtree(tmp_pt, res);
        }

        const std::string& JsonDumpReader::getRecordName(std::size_t ts_id) {
            return m_calls.at(ts_id).m_name;
        }

        const std::vector<int64_t>& JsonDumpReader::getTimestamps() const {
            return m_timestamps;
        }

        const std::map<std::string, std::vector<std::size_t>>& JsonDumpReader::getGropedTimestamps() const {
            return m_grouped_timestamps;
        }

        bool JsonDumpReader::findBracket(const std::string& src, bool is_begin) {
            const std::string to_find = is_begin ? "{" : "}";
            return src.find(to_find) != std::string::npos;
        }

        JsonDumpReader::JsonDumpReader(const std::string &file_name)
        {
            m_file.open(file_name.c_str());

            if (!m_file.is_open())
            {
                throw std::runtime_error("failed to open file '" + file_name + "'");
            }

            // TODO : check version

            std::string line;
            while (std::getline(m_file, line))
            {
                std::string time_val;
                if (readKey(line, s_time_key, time_val))
                {
                    m_timestamps.push_back(std::atoll(time_val.c_str()));

                    std::getline(m_file, line);
                    std::string name_val;
                    if (!readKey(line, s_name_key, name_val))
                    {
                        throw std::runtime_error("something wrong with file structure");
                    }

                    // skip comma separator
                    std::getline(m_file, line);

                    // skip "params" keyword
                    std::getline(m_file, line);

                    m_grouped_timestamps[name_val].push_back(m_calls.size());

                    std::fstream::pos_type back_offset = 2;
                    back_offset = (line.find('{') == std::string::npos) ? std::fstream::pos_type(3)
                                                                        : back_offset;
                    // return to "{" symbol
                    m_calls.push_back({name_val, m_file.tellg() - back_offset});
                }
            }

            m_file.close();
            m_file.open(file_name.c_str());
        }

        void JsonDumpReader::jump(std::size_t ts_id)
        {
            SCall call = m_calls[ts_id];
            m_file.seekg(call.m_pos);

            std::string line;
            std::stringstream ss;
            int brackets = 0;
            do
            {
                std::getline(m_file, line);
                brackets += findBracket(line, true);
                brackets -= findBracket(line, false);
                ss << line << std::endl;
            }
            while (brackets);

            boost::property_tree::read_json(ss, m_curr_pt);
        }

        bool JsonDumpReader::readKey(const std::string& src, const std::string& key, std::string& val)
        {
            const std::size_t key_len = key.length();
            const std::size_t key_begin_pos = src.find(key.c_str(), key_len);
            if (key_begin_pos == std::string::npos)
            {
                return false;
            }

            const std::size_t key_end_pos = key_begin_pos + key_len;
            const std::size_t val_begin_pos = src.find("\"", key_end_pos) + 1;
            const std::size_t val_end_pos = src.find("\"", val_begin_pos);
            val = src.substr(val_begin_pos, val_end_pos - val_begin_pos);
            return true;
        }

    '''
}
