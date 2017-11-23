package org.genivi.commonapi.core.generator

import java.util.Map
import java.util.HashMap

class FNativeInjections {

    def String generateNativeInjection(String tag)
    {
        val Map<String, String> data = new HashMap<String, String>()

        data.put("VideoSourceInclude", "
#include <opencv2/opencv.hpp>
#include <shared_memory_buffer/CSharedMemoryBuffer.hpp>
        ")

        data.put("VideoSourceCtor", "
/* TODO: get rid of STATIC */
static int width = 0;
static int height = 0;
static cv::VideoWriter capture;
        ")

        data.put("WRITE_VideoSourceCamerasInfo", "
/* TODO: do this for all cameras */
auto cameraInfo = data[0];
width = cameraInfo.getFrameInfo().getImageSize().getWidth();
height = cameraInfo.getFrameInfo().getImageSize().getHeight();
capture.open(\"Video.avi\", cv::VideoWriter::fourcc('M', 'J', 'P', 'G'), 30, cv::Size(width, height));
        ")

        data.put("WRITE_VideoSourceFrames", "
if (data.empty())
{
    std::cout << \"Received empty frame data\";
    return;
}
std::cout << \"Received frame: ts=\" << data[0].getTime() << std::endl;
ManagedSharedMemoryBuffer::CSharedMemoryBuffer buff(data[0].getKey());
uint8_t* frame_data = buff.getBuffer();

/* TODO: add different color-spaces support */
cv::Mat frame(height, width, CV_8UC3, frame_data);
capture << frame;
cv::imshow(\"frame\", frame);
cv::waitKey(1);
        ")

        data.put("VideoSourcePlaybackIncludes", "
#include <opencv2/opencv.hpp>
#include <shared_memory_buffer/CSharedMemoryBuffer.hpp>
        ")

        data.put("VideoSourcePlaybackCtor", "
static cv::VideoCapture capture;
capture.open(\"Video.avi\"); // TODO: no hardcode
        ")

        data.put("READ_VideoSourceFrames", "
static std::size_t prev_ts = m_curr_ts;
if (prev_ts != m_curr_ts)
{
    capture.set(CV_CAP_PROP_POS_FRAMES, m_curr_ts);
    prev_ts = m_curr_ts + 1;
}
cv::Mat frame;
capture >> frame;
if (frame.empty())
{
    return;
}

std::size_t buff_size = frame.cols * frame.rows * 3;
ManagedSharedMemoryBuffer::CSharedMemoryBuffer shm_buffer(
    buff_size,
    ManagedSharedMemoryBuffer::c_default_timeout,
    ManagedSharedMemoryBuffer::c_default_timeout);

memcpy(shm_buffer.getBuffer(), frame.data, buff_size);

std::stringstream ss;
for (auto a :shm_buffer.getKey())
{
    ss << (int)a;
}
std::cout << ss.str() << \" KEY\" << std::endl;
data[0].setKey(shm_buffer.getKey());
        ")

        data.put("AugmentationEngineClientPlaybackPrivateMembers", "
std::map<uint64_t, uint64_t> m_object_indexes;
bool defineObjId(Ipc::RenderingEngineTypes::ObjectId& obj_id)
{
    auto item = m_object_indexes.find(obj_id);
    if (item == m_object_indexes.end()) {
        std::cout << \"Warning: request to use not existing object \" << obj_id << std::endl;
        return false;
    }
    obj_id = item->second;
    return true;
}
        ")

        data.put("AugmentationEngine_addObject_end_ClientPlayback", "
m_object_indexes[data.get_object_id()] = object_id;
        ")

        data.put("AugmentationEngine_getObjectProperty_begin_ClientPlayback", "
auto object_id = data.get_object_id();
if (!defineObjId(object_id)) {
    return;
}
data.set_object_id(object_id);
        ")

        data.put("AugmentationEngine_updateObjectProperties_begin_ClientPlayback", "
auto object_id = data.get_object_id();
if (!defineObjId(object_id)) {
    return;
}
data.set_object_id(object_id);
        ")

        data.put("AugmentationEngine_sendObjectCommand_begin_ClientPlayback", "
auto object_id = data.get_object_id();
if (!defineObjId(object_id)) {
    return;
}
data.set_object_id(object_id);
        ")

        data.put("AugmentationEngine_removeObject_begin_ClientPlayback", "
auto object_id = data.get_object_id();
if (!defineObjId(object_id)) {
    return;
}
data.set_object_id(object_id);
        ")

        if (data.containsKey(tag))
        {
            return data.get(tag);
        }
    }
}
