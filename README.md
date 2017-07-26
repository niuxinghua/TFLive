# TFLive

v1.0 2017-7-3 完成视频输出流程

v1.1 2017-7-6 完成音频输出流程

v1.2 2017-7-26 优化处理：
 1. 将OpenGL显示流程移到副线程，避免阻塞主线程
 2. packetQueue和frameQueue添加入队和出队的挑拣锁，在队列空或满时阻塞线程，避免无用的运行，占用cpu
 3. 绘制gl_triangle改为gl_triangle_strip
