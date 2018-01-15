package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor

// TODO: rename
class FXmlDumpReader {
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

        class XmlDumpReader
        {
        public:
            XmlDumpReader(const std::string& file_name);
            const std::vector<int64_t>& getTimestamps() const;
            const std::map<std::string, std::vector<std::size_t>>& getGropedTimestamps() const;

            const std::string& getRecordName(std::size_t ts_id);

            template<class T>
            void read(std::size_t ts_id, T& res);

        private:
            bool isContainsTag(const std::string& src, const std::string& key, bool is_closed = false);

            std::ifstream m_file;

            std::vector<SCall> m_calls;
            std::vector<int64_t> m_timestamps;
            std::map<std::string, std::vector<std::size_t>> m_grouped_timestamps;
        };

        XmlDumpReader::XmlDumpReader(const std::string &file_name)
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
                if (isContainsTag(line, s_header_tag))
                {
                    std::stringstream ss;
                    while (std::getline(m_file, line)) {
                        if (isContainsTag(line, s_header_tag, true)) {
                            break;
                        }
                        ss << line;
                    }

                    «fInterface.dumperCommandTypeName» cmd;
                    DataSerializer::readXmlFromStream(ss, cmd);

                    // skip <params>
                    std::getline(m_file, line);

                    auto begin_pos = m_file.tellg();
                    decltype(begin_pos) end_pos;

                    do {
                        end_pos = m_file.tellg();
                    } while (std::getline(m_file, line)
                          && !isContainsTag(line, s_content_tag, true));

                    m_timestamps.push_back(cmd.time);
                    m_grouped_timestamps[cmd.name].push_back(m_calls.size());
                    m_calls.push_back({cmd.name, begin_pos, end_pos});
                }
            }

            std::cout << "Found " << m_timestamps.size() << " items" << std::endl;

            m_file.close();
            m_file.open(file_name.c_str());
        }

        template<class T>
        void XmlDumpReader::read(std::size_t ts_id, T& res)
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
            std::cout << "Warning: failed to read " << call.m_name
                      << " (" << m_timestamps[ts_id] << ")"
                      << " probably because of it contains nan/inf values" << std::endl;
            }
        }

        const std::string& XmlDumpReader::getRecordName(std::size_t ts_id) {
            return m_calls.at(ts_id).m_name;
        }

        const std::vector<int64_t>& XmlDumpReader::getTimestamps() const {
            return m_timestamps;
        }

        const std::map<std::string, std::vector<std::size_t>>& XmlDumpReader::getGropedTimestamps() const {
            return m_grouped_timestamps;
        }

        bool XmlDumpReader::isContainsTag(const std::string& src, const std::string& key, bool is_closed)
        {
            return src.find(std::string("<") + (is_closed ? "/" : "") + key + ">", 0) != std::string::npos;
        }

    '''
}
