# asset-generator
## prerequisite 
* `openssl`
* `kubectl` or `oc`
* `kind`
* `kbld` ( [how to install](https://carvel.dev/kbld/docs/v0.44.x/install/))
* cf

## Cluster creation 
1. clone korifi repo 

```bash
git clone git@github.com:cloudfoundry/korifi.git
```

2. expose privileged port
for 80 and 443

```bash
sudo setcap cap_net_bind_service=ep $(which rootlesskit)
systemctl --user restart docker
```
<!-- 
3. create local docker registry 
docker run -d -p 5000:5000 --name registry registry:latest -->

3. Create cluster with Korifi

```bash
cd korifi/scripts
./deploy-on-kind korifi
```

   1. Troubleshooting

      In Linux platforms, if `oc -n korifi-installer logs --follow job/install-korifi`
      prints `failed to create fsnotify watcher: too many open files%` execute

      ```bash
      sudo sysctl fs.inotify.max_user_watches=1048576
      sudo sysctl fs.inotify.max_user_instances=8192
      ```
   2. `envoy-korifi` can't start

      `oc logs -n korifi-gateway envoy-korifi-fvpcd -c envoy`

      ```bash
      [2024-12-10 14:31:38.733][1][critical][assert] [source/common/filesystem/inotify/watcher_impl.cc:23] assert failure: inotify_fd_ >= 0. Details: Consider increasing value of user.max_inotify_watches via sysctl
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:127] Caught Aborted, suspect faulting address 0xfffe00000001
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:111] Backtrace (use tools/stack_decode.py to get line numbers):
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:112] Envoy version: e3b4a6e9570da15ac1caffdded17a8bebdc7dfc9/1.31.3/Clean/RELEASE/BoringSSL
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:114] Address mapping: 55f940a78000-55f9434d9000 /usr/local/bin/envoy
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:121] #0: [0x7f43bfa42520]
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:127] Caught Segmentation fault, suspect faulting address 0x0
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:111] Backtrace (use tools/stack_decode.py to get line numbers):
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:112] Envoy version: e3b4a6e9570da15ac1caffdded17a8bebdc7dfc9/1.31.3/Clean/RELEASE/BoringSSL
      [2024-12-10 14:31:38.733][1][critical][backtrace] [./source/server/backtrace.h:114] Address mapping: 55f940a78000-55f9434d9000 /usr/local/bin/envoy
      [2024-12-10 14:31:38.734][1][critical][backtrace] [./source/server/backtrace.h:121] #0: [0x7f43bfa42520]
      ```

      **Solution:**

      To fix it temporarily (until next reboot)
      ```bash
      sudo sysctl -w fs.inotify.max_user_watches=524288
      sudo sysctl -w fs.inotify.max_user_instances=1024
      ```
      To fix it permanently, you need to use sysctl to configure your kernel on boot.
      Write the following line to a appropriately-named file under `/etc/sysctl.d/`, for example `/etc/sysctl.d/inotify.conf`:
      ```bash
      fs.inotify.max_user_watches=524288
      fs.inotify.max_user_instances=1024
      ```

   3. `envoy-korifi` service is pending
   
      ```bash
         oc get svc -n korifi-gateway  envoy-korifi
         NAME           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                           AGE
         envoy-korifi   LoadBalancer   10.96.92.253   <pending>     32080:31449/TCP,32443:31341/TCP   102m
         ----------------------------------------------------------------------------------------------------
      ```

      need to change `korifi/scripts/assets/kind-config.yaml`. 

      Apply this patch in `korifi` repository

      ```bash 
      diff --git a/scripts/assets/kind-config.yaml b/scripts/assets/kind-config.yaml
      index 74915116..a3c8e3df 100644
      --- a/scripts/assets/kind-config.yaml
      +++ b/scripts/assets/kind-config.yaml
      @@ -11,6 +11,7 @@ containerdConfigPatches:
               insecure_skip_verify = true
      nodes:
      - role: control-plane
      +- role: worker
         extraPortMappings:
         - containerPort: 32080
         hostPort: 80
      ```
   4. deployments `korifi-api-deployment` not starting because of 
      ```bash
      oc describe deployments.apps korifi-api-deployment -n korifi             
      [......]
      [......]
      Error creating: pods "korifi-controllers-controller-manager-5d8f5db889-gnwqb" is forbidden: violates PodSecurity "restricted:latest": unrestricted capabilities (container "manager" must not include "SYS_PTRACE" in securityContext.capabilities.add), runAsNonRoot != true (pod and container "manager" must not set securityContext.runAsNonRoot=false)
      ```

      Do not use flag `--debug` execute when executing `./deploy-on-kind korifi`.
