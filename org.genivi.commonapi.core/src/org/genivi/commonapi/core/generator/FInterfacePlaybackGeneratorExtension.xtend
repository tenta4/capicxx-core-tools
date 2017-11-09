package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants

class FInterfacePlaybackGeneratorExtension {
    @Inject private extension FrancaGeneratorExtensions
    @Inject private extension FNativeInjections

    def generatePlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid) {

        fileSystemAccess.generateFile(fInterface.playbackSourcePath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGeneratePlayback(deploymentAccessor, modelid))
    }

    def private extGeneratePlayback(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #include <fstream>
        #include <iostream>
        #include <vector>
        #include <functional>

        #include "preprocessor/AdaptNamedAttrsAdt.hpp"
        #include "json_serializer/JsonSerializer.hpp"
        #include <«fInterface.serrializationHeaderPath»>
        #include <«fInterface.getStubHeaderPath»>

        // TODO: move to CDataProvider
        «generateNativeInjection(fInterface.name + "PlaybackIncludes")»

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
                class «attribute.name»Element;
            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            class «broadcast.name»Element;
        «ENDFOR»

        class CVisitor
        {
        public:
            CVisitor(std::shared_ptr<«fInterface.getStubClassName»> transport)
                : m_transport(transport) {}

            «FOR attribute : fInterface.attributes»
                «IF attribute.isObservable»
                    void visit«attribute.name»(const «attribute.name»Element&);
                «ENDIF»
            «ENDFOR»

            «FOR broadcast : fInterface.broadcasts»
                void visit«broadcast.name»(const «broadcast.name»Element& data);
            «ENDFOR»

        private:
            std::shared_ptr<«fInterface.getStubClassName»> m_transport;
        };

        class IElement
        {
            virtual void visit(CVisitor& visitor) = 0;
        };

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            class «attribute.name»Element : public IElement
            {
            public:
                «attribute.name»Element(const «attribute.getTypeName(fInterface, true)»& data)
                    : m_data(data){}

                void visit(CVisitor& visitor) override {
                    visitor.visit«attribute.name»(*this);
                }

                const «attribute.getTypeName(fInterface, true)»& getData() const {
                    return m_data;
                }

            private:
                «attribute.getTypeName(fInterface, true)» m_data;
            }; // class «attribute.name»Element

            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            class «broadcast.name»Element : public IElement
            {
            public:
                void visit(CVisitor& visitor) override {
                    visitor.visit«broadcast.name»(*this);
                }

                «FOR argument : broadcast.outArgs»
                    void set_«argument.name»(const «argument.getTypeName(fInterface, true)»& data) {
                        m_«argument.name» = data;
                    }

                    const «argument.getTypeName(fInterface, true)»& get_«argument.name»() const {
                        return m_«argument.name»;
                    }
                «ENDFOR»
            private:
                «FOR argument : broadcast.outArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
            }; // class «broadcast.name»Element
        «ENDFOR»

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            void CVisitor::visit«attribute.name»(const «attribute.name»Element& data) {
                m_transport->fire«attribute.className»Changed(data.getData());
                std::cout << "«attribute.name»" << std::endl;
            }
            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            void CVisitor::visit«broadcast.name»(const «broadcast.name»Element& data) {
                m_transport->fire«broadcast.name»Event(
                «var boolean first = true»
                «FOR argument : broadcast.outArgs»
                    «IF !first»,«ENDIF»«{first = false; ""}» data.get_«argument.name»()
                «ENDFOR»
                );
                std::cout << "«broadcast.name»" << std::endl;
            }
        «ENDFOR»

        struct SCall
        {
            std::string m_name;
            std::fstream::pos_type m_pos;
        };

        struct STime
        {
            std::size_t m_ts_idx;
            int64_t m_ts;
            bool operator < (const STime& in) const
            {
                return m_ts < in.m_ts;
            }
        };

        static const std::string s_time_key = "\"time\"";
        static const std::string s_name_key = "\"name\"";

        class JsonDumpReader
        {
        public:
            JsonDumpReader(const std::string& file_name);
            const std::vector<int64_t>& getTimestamps() const;
            const std::map<std::string, std::vector<STime>>& getGropedTimestamps() const;

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
            std::map<std::string, std::vector<STime>> m_grouped_timestamps;

            std::map<std::string, std::function<void(CVisitor&, boost::property_tree::ptree pt)>> m_functions;
            boost::property_tree::ptree m_curr_pt;
        };

        template<class T>
        void JsonDumpReader::readItem(const std::string& tag, T& res) {
            boost::property_tree::ptree tmp_pt = m_curr_pt.get_child(tag);
            JsonSerializer::readFromPtree(tmp_pt, res);
        }

        const std::string& JsonDumpReader::getRecordName(std::size_t ts_id) {
            return m_calls.at(ts_id).m_name;
        }

        const std::vector<int64_t>& JsonDumpReader::getTimestamps() const {
            return m_timestamps;
        }

        const std::map<std::string, std::vector<STime>>& JsonDumpReader::getGropedTimestamps() const {
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

                    m_grouped_timestamps[name_val].push_back({m_calls.size(), m_timestamps.back()});

                    // return to "{" symbol
                    m_calls.push_back({name_val, m_file.tellg() - std::fstream::pos_type(2)});
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

        const static int64_t s_jump_time = 1000000;

        class CDataProvider
        {
        public: // methods
            CDataProvider(const std::string& file_name)
                : m_reader(file_name)
                , m_curr_ts(std::numeric_limits<std::size_t>::max())
            {
                initReaders();
            }
            void provide(std::size_t ts_id, CVisitor& visitor)
            {
                if (ts_id >= m_reader.getTimestamps().size())
                {
                    throw std::runtime_error("Request data for non-existent timestamp id");
                }
                std::size_t prev_ts = m_curr_ts;
                m_curr_ts = ts_id;

                std::cout << prev_ts << " " << m_curr_ts << " PREV AND CURR\n";
                if (m_curr_ts < prev_ts || // jump back
                    (m_reader.getTimestamps()[m_curr_ts] - m_reader.getTimestamps()[prev_ts]) > s_jump_time) // jump forward
                {
                    std::cout << " jump " << m_reader.getTimestamps()[ts_id] << std::endl;
                    for (auto record: m_reader.getGropedTimestamps())
                    {
                        std::cout << record.first << " ";
                        providePastRecord(ts_id, record.second, visitor);
                    }
                }
                else
                {
                    provideRecord(ts_id, visitor);
                }
            }

            const std::vector<int64_t>& getTimestamps() {
                return m_reader.getTimestamps();
            }
        private: // fields

            JsonDumpReader m_reader;
            std::map<std::string, std::function<void(CVisitor&)>> m_readers;
            std::size_t m_curr_ts;

        private: // methods
            void providePastRecord(std::size_t ts_id, const std::vector<STime>& storage, CVisitor &visitor)
            {
                int64_t time = m_reader.getTimestamps()[ts_id];
                auto iter = std::upper_bound(storage.begin(), storage.end(), STime{ts_id, time});
                if (iter == storage.begin())
                {
                    // no records before this time
                    std::cout << ": past ts not exists\n";
                    return;
                }
                iter = std::prev(iter);
                std::cout << m_reader.getTimestamps()[iter->m_ts_idx] << " past ts\n";
                provideRecord(iter->m_ts_idx, visitor);
            }

            void provideRecord(std::size_t ts_id, CVisitor &visitor)
            {
                m_reader.jump(ts_id);

                auto func = m_readers.find(m_reader.getRecordName(ts_id));
                if (func != m_readers.end())
                {
                    func->second(visitor);
                }
                else
                {
                    std::cout << "WARNING: " << m_reader.getRecordName(ts_id)
                              << " will not processed" << std::endl;
                }
            }


            void initReaders()
            {
                «generateNativeInjection(fInterface.name + "PlaybackCtor")»

                m_readers = {
                «FOR attribute : fInterface.attributes»
                    «IF attribute.isObservable»
                        {"«attribute.className»", [this](CVisitor& visitor)
                            {
                                «attribute.getTypeName(fInterface, true)» data;
                                m_reader.readItem("«attribute.name»", data);
                                «generateNativeInjection("READ_" + fInterface.name + attribute.name)»

                                «attribute.name»Element data_elem(data);
                                visitor.visit«attribute.name»(data_elem);
                            }
                        },
                    «ENDIF»
                «ENDFOR»
                «FOR broadcast : fInterface.broadcasts»
                    {"«broadcast.className»", [this](CVisitor& visitor)
                        {
                            «broadcast.name»Element data_elem;
                            «FOR argument : broadcast.outArgs»
                                «argument.getTypeName(fInterface, true)» «argument.name»_data;
                                m_reader.readItem("«argument.name»", «argument.name»_data);
                                «generateNativeInjection("READ_" + fInterface.name + argument.name)»

                                data_elem.set_«argument.name»(«argument.name»_data);
                            «ENDFOR»
                            visitor.visit«broadcast.name»(data_elem);
                        }
                    },
                «ENDFOR»
                };
            }
        };

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

        #include <CommonAPI/CommonAPI.hpp>
        #include <timeService/CTimeClient.hpp>
        #include <«fInterface.stubDefaultHeaderPath»>

        int main(int argc, char** argv)
        {
            «fInterface.generateNamespaceUsage»

            // TODO: catch SIGINT

            if (argc < 3)
            {
                std::cout << "Format: filename serviceName\n";
                return 0;
            }

            std::shared_ptr<CommonAPI::Runtime> runtime = CommonAPI::Runtime::get();
            std::shared_ptr<«fInterface.stubDefaultClassName»> service = std::make_shared<«fInterface.stubDefaultClassName»>();
            runtime->registerService("local", argv[2], service);
            std::cout << "Successfully Registered Service!" << std::endl;

            CVisitor visitor(service);
            CDataProvider provider(argv[1]);

            TimeService::CTimeClient time_client(provider.getTimestamps());
            while (1)
            {
                std::size_t idx = static_cast<std::size_t>(time_client.waitForNexTimestamp());
                provider.provide(idx, visitor);
            }
            return 0;
        }

    '''
}
