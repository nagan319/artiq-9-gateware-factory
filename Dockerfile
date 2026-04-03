FROM vivado-2024.2-env

# Install fake_udev stub as the system libudev so Vivado's dlopen-based
# webtalk/license calls get safe no-ops instead of crashing on Docker's
# missing udev kernel data. The .so was compiled inside the base image.
USER root
RUN cp /usr/local/lib/fake_udev.so /lib/x86_64-linux-gnu/libudev.so.1
# artiq-zynq's Vivado FHS wrapper expects Vivado at /opt/Xilinx/Vivado/2024.2/
# and nixConfig sets extra-sandbox-paths = "/opt". Symlink our install location.
RUN ln -s /tools/Xilinx /opt/Xilinx
USER builder
RUN mkdir -p /home/builder/.Xilinx/Vivado
COPY --chown=builder:builder Vivado_init.tcl /home/builder/.Xilinx/Vivado/Vivado_init.tcl
COPY --chown=builder:builder sources.conf /home/builder/sources.conf
COPY --chown=builder:builder entrypoint.sh /home/builder/entrypoint.sh
RUN chmod +x /home/builder/entrypoint.sh

ENTRYPOINT ["/home/builder/entrypoint.sh"]
