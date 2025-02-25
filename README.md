#### Instructions

1. Clone this repository
   ```
   git clone github.com/pushkarnk/chiseled-17-crac && cd chiseled-17-crac
   ```

2. Build the chiseled C/R image
   ```
   docker build --network=host -t crac-17-chiseled .
   ```

The next steps assume the crac-17-chiseled:latest image is now build.

3. Change directory to the petclinic example.
   ```
   cd petclinic-example
   ```

4. Build the petclinic-checkpoint image. This builds on top of crac-17-chiseled.
   The **target/spring-petclinic-3.4.0-SNAPSHOT.jar** is produced by `mvn package` run against [spring-petclinic](https://github.com/spring-projects/spring-petclinic)
   ```
   docker build -f Dockerfile-petclinic-checkpoint -t petclinic-checkpoint .
   ```

5. Run the checkpoint image:
   ```
   docker run --network=host \
     --cap-add=CHECKPOINT_RESTORE \
     --cap-add=SYS_PTRACE \
     -p 8080:8080 \
     -v /tmp:/tmp -v ./snapshot:/home/app/snapshot \
     petclinic-checkpoint
   ```
   The PetClinicApplication must be reachable using localhost:8080 in around 10 seconds.

6. Checkpoint the PetClinic application. In a new terminal issue:
   ```
   $ docker exec 02b9bb9308b2 /opt/java/bin/jcmd
   130 /home/app/target/spring-petclinic-3.4.0-SNAPSHOT.jar
   270 jdk.jcmd/sun.tools.jcmd.JCmd
   ```
   Here, 02b9bb9308b2 is the "container id" of the container running PetClinic. Note down the pid of the petclinic process (**130** here).
   Next, checkpoint PID 130:
   ```
   $ docker exec 02b9bb9308b2 /opt/java/bin/jcmd 130 JDK.checkpoint
   130:
   CR: Checkpoint ...
   ```
7. Move back to the initial terminal. The application must now be killed. And you must find the checkpoint data under **./snapshot**.
   Please delete dump4.log from the `snapshot` directory.
   ```
   sudo rm ./snapshot/dump4.log
   ```

8. Build the chiseled restore container image.
   ```
   docker build -f Dockerfile-petclinic-restore -t petclinic-restore
   ```

9. Finally, run the restore image:
   ```
   docker run --user root \
     -p 8080:8080 \
     --network=host \
     --cap-add CAP_CHECKPOINT_RESTORE \
     --cap-add CAP_NET_ADMIN \
     --cap-add CAP_SYS_ADMIN \
     --cap-add CAP_SYS_PTRACE \
     -v /tmp:/tmp \
     petclinic-restore
   ```
   The application must now come up in ~15 ms.
