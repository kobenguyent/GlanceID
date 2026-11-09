#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <security/pam_appl.h>
#include <security/pam_modules.h>

#define GLANCEID_PATH "/Applications/GlanceID.app/Contents/MacOS/GlanceID"

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    // Check if GlanceID application exists
    if (access(GLANCEID_PATH, X_OK) != 0) {
        return PAM_AUTH_ERR;
    }

    // Only authenticate interactive terminals
    if (!isatty(STDIN_FILENO) && !isatty(STDERR_FILENO)) {
        return PAM_AUTH_ERR;
    }

    fprintf(stderr, "\033[1;36m👁️ GlanceID Face ID:\033[0m Glancing at camera...\n");

    pid_t pid = fork();
    if (pid < 0) {
        return PAM_AUTH_ERR;
    }

    if (pid == 0) {
        // Drop root privileges so GlanceID runs as the logged-in user
        // (This allows accessing user TCC camera permission and local profile)
        uid_t real_uid = getuid();
        gid_t real_gid = getgid();
        if (real_uid != 0) {
            setgid(real_gid);
            setuid(real_uid);
        }

        execl(GLANCEID_PATH, "GlanceID", "--verify", (char *)NULL);
        _exit(1);
    }

    int status = 0;
    waitpid(pid, &status, 0);

    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        fprintf(stderr, "\033[1;32m✅ Face ID Verified!\033[0m\n");
        return PAM_SUCCESS;
    }

    fprintf(stderr, "\033[0;33mFace ID not matched. Falling back to password...\033[0m\n");
    return PAM_AUTH_ERR;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}
