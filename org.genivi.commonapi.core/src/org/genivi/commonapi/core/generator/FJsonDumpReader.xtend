package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor

// TODO: rename
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
            std::fstream::pos_type m_end_pos;
        };

        static const std::string s_time_key = "time";
        static const std::string s_name_key = "name";

        class JsonDumpReader
        {
        public:
            JsonDumpReader(const std::string& file_name);
            const std::vector<int64_t>& getTimestamps() const;
            const std::map<std::string, std::vector<std::size_t>>& getGropedTimestamps() const;

            const std::string& getRecordName(std::size_t ts_id);

            template<class T>
            void read(std::size_t ts_id, T& res);

        private:
            bool readKey(const std::string& src, const std::string& key, std::string& val);

            std::ifstream m_file;

            std::vector<SCall> m_calls;
            std::vector<int64_t> m_timestamps;
            std::map<std::string, std::vector<std::size_t>> m_grouped_timestamps;
        };

        template<class T>
        void JsonDumpReader::read(std::size_t ts_id, T& res)
        {
            SCall call = m_calls[ts_id];
            m_file.seekg(call.m_pos);

            std::string line;
            std::stringstream ss;
            while (m_file.tellg() < call.m_end_pos)
            {
                std::getline(m_file, line);
                ss << line << std::endl;
            }

            if (!DataSerializer::readXmlFromStream(ss, res))
            {
                throw std::runtime_error("Failed to read " + call.m_name);
            }
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
                        throw std::runtime_error("Something wrong with file structure");
                    }

                    // skip </declaration>
                    std::getline(m_file, line);

                    // skip <params>
                    std::getline(m_file, line);

                    auto begin_pos = m_file.tellg();
                    decltype(begin_pos) end_pos;

                    do {
                        end_pos = m_file.tellg();
                        std::getline(m_file, line);
                    } while (line.find("</params>", 0) == std::string::npos);

                    m_grouped_timestamps[name_val].push_back(m_calls.size());
                    m_calls.push_back({name_val, begin_pos, end_pos});
                }
            }

            std::cout << "Found " << m_timestamps.size() << " items" << std::endl;

            m_file.close();
            m_file.open(file_name.c_str());
        }

        bool JsonDumpReader::readKey(const std::string& src, const std::string& key, std::string& val)
        {
            const std::string begin_tag = "<" + key + ">";
            const std::string close_tag = "</" + key + ">";

            const std::size_t key_begin_pos = src.find(begin_tag.c_str(), 0);
            if (key_begin_pos == std::string::npos)
            {
                return false;
            }

            const std::size_t key_end_pos = key_begin_pos + begin_tag.length();
            const std::size_t val_end_pos = src.find(close_tag, key_end_pos);

            val = src.substr(key_end_pos, val_end_pos - key_end_pos);
            return true;
        }

    '''
}
