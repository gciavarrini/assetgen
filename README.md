# asset-generator
## Prerequisite 
* `openssl`
* `kubectl` or `oc`
* `kind`
* `kbld` ( [how to install](https://carvel.dev/kbld/docs/v0.44.x/install/))
* `cf`

## Cluster creation 

1. Clone korifi repo 

   ```bash
   git clone git@github.com:cloudfoundry/korifi.git
   ```

   > [!IMPORTANT]
   > There are known issues with the deployment process on Kind cluster.

   To address these issues, you can use a [forked repository](https://github.com/gciavarrini/korifi/tree/fix-deploy-on-kind)
   that includes fixes for deploying Korifi on Kind. 
   
   This repo contains: 
   * [7929fed5](https://github.com/cloudfoundry/korifi/commit/7929fed5bae427f21eb26f72bbbf78a56cd4c970) Change kind config to use 2 nodes
   * [9a59dcaa](https://github.com/cloudfoundry/korifi/commit/9a59dcaa05dca62317d990b834e3642a9644d79c) Fix helm chart update
   * [3d3b380e](https://github.com/cloudfoundry/korifi/commit/3d3b380ee3a8f9b575c6a9d9158da0194014fe6f) Duplicated resource `cfserviceinstances/status`

   ```bash
   git clone git@github.com:gciavarrini/korifi.git
   ```

2. Expose privileged port `80` and `443`

   ```bash
   sudo setcap cap_net_bind_service=ep $(which rootlesskit)
   systemctl --user restart docker
   ```

3. Create cluster with Korifi

   ```bash
   cd korifi/scripts
   ./deploy-on-kind korifi
   ```
## Troubleshooting
   1. Job `install-korifi` fails with `fsnotify watcher: too many open files`

      In Linux platforms, if `oc -n korifi-installer logs --follow job/install-korifi`
      prints `failed to create fsnotify watcher: too many open files%` execute

      **Solution:**

       To fix it temporarily (until next reboot)
      
      ```bash
      sudo sysctl -w fs.inotify.max_user_watches=1048576
      ```
      
      To fix it permanently, you need to use sysctl to configure your kernel on boot.
      Write the following line to a appropriately-named file under `/etc/sysctl.d/`, for example `/etc/sysctl.d/inotify.conf`:
      
      ```bash
      fs.inotify.max_user_watches=1048576
      ```

   2. Pod `envoy-korifi` can't start

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
      sudo sysctl -w fs.inotify.max_user_watches=1048576
      sudo sysctl -w fs.inotify.max_user_instances=8192
      ```
      
      To fix it permanently, you need to use sysctl to configure your kernel on boot.
      Write the following line to a appropriately-named file under `/etc/sysctl.d/`, for example `/etc/sysctl.d/inotify.conf`:
      
      ```bash
      fs.inotify.max_user_watches=1048576
      fs.inotify.max_user_instances=8192
      ```

   3. Service `envoy-korifi` is pending
   
      ```bash
         >> oc get svc -n korifi-gateway  envoy-korifi
         NAME           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                           AGE
         envoy-korifi   LoadBalancer   10.96.92.253   <pending>     32080:31449/TCP,32443:31341/TCP   102m
         ----------------------------------------------------------------------------------------------------
      ```
      **Solution:**

      Need to change `korifi/scripts/assets/kind-config.yaml` to use two nodes as per [contour doc](https://projectcontour.io/docs/main/guides/kind/)
      
      Apply this patch in `korifi` repository

      ```bash
      git apply << EOF
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
      EOF
      ```

      and recreate the cluster

      ```bash
      kind delete cluster -n korifi
      ./deploy-on-kind.sh korifi
      ```

   4. Deployment `korifi-api-deployment` can't start

      ```bash
      >> oc describe deployments.apps korifi-api-deployment -n korifi
      [......]
      [......]
      Error creating: pods "korifi-controllers-controller-manager-5d8f5db889-gnwqb" is forbidden: violates PodSecurity "restricted:latest": unrestricted capabilities (container "manager" must not include "SYS_PTRACE" in securityContext.capabilities.add), runAsNonRoot != true (pod and container "manager" must not set securityContext.runAsNonRoot=false)
      ```
      **Solution:**

      Do not use flag `--debug` execute when executing `./deploy-on-kind korifi`.
