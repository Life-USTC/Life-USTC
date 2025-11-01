#!/usr/bin/env bash
set -Eeuo pipefail

# Config (env-overridable)
SCREENSHOTS_DIR=${SCREENSHOTS_DIR:-screenshots}
OUTPUT_MD=${OUTPUT_MD:-screenshots_comment.md}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-local/preview}
GITHUB_RUN_ID=${GITHUB_RUN_ID:-$(date +%s)}
# If provided (e.g., from CI), should end with a slash, e.g. https://<org>.github.io/<repo>/
PAGES_URL=${PAGES_URL:-}

# Derive URLs / layout
RUN_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
BASE_URL=""
if [[ -n "${PAGES_URL}" ]]; then
  BASE_URL="${PAGES_URL}run-${GITHUB_RUN_ID}/screenshots"
fi
COLS=${COLS:-3}

# Start markdown
{
  echo "# iOS UI Screenshots"
  echo
  echo "- Workflow run: ${RUN_URL}"
  echo "- Artifact: ios-screenshots-${GITHUB_RUN_ID}"
  echo
  if [[ -n "${BASE_URL}" ]]; then
    echo "- Public preview: ${BASE_URL}"
    echo
  fi

  if [[ -d "${SCREENSHOTS_DIR}" ]]; then
    # Iterate languages robustly (spaces-safe, stable order)
    while IFS= read -r -d '' langdir; do
      lang=${langdir#${SCREENSHOTS_DIR}/}
      lang=${lang%/}
      echo "## ${lang}"
      echo

      # Any PNGs in this language?
      if compgen -G "${SCREENSHOTS_DIR}/${lang}/*.png" > /dev/null; then
        if [[ -n "${BASE_URL}" ]]; then
          # Inline image gallery (public) as a table grid
          # Header
          header="|"; sep="|"; i=1
          while [[ $i -le ${COLS} ]]; do
            header+="  |"; sep+=":--:|"; i=$((i+1))
          done
          echo "$header"  # e.g., |  |  |
          echo "$sep"     # e.g., |:--:|:--:|

          # Rows
          row_count=0
          row_cells=()
          while IFS= read -r -d '' imgpath; do
            img_rel=${imgpath#${SCREENSHOTS_DIR}/}
            urlpath=${img_rel// /%20}
            cell="![${img_rel}](${BASE_URL}/${urlpath})<br><sub>${img_rel}</sub>"
            row_cells+=("$cell")
          done < <(find "${SCREENSHOTS_DIR}/${lang}" -maxdepth 1 -type f -name "*.png" -print0 | sort -z)

          # Emit rows with COLS cells
          idx=0
          total=${#row_cells[@]}
          while [[ $idx -lt $total ]]; do
            line="|"
            for ((c=0; c<COLS; c++)); do
              if [[ $((idx+c)) -lt $total ]]; then
                line+=" ${row_cells[$((idx+c))]} |"
              else
                line+="  |"
              fi
            done
            echo "$line"
            idx=$((idx+COLS))
          done
          echo
        else
          # Fall back to listing files when no public URL
          echo "| File |"
          echo "|---|"
          while IFS= read -r -d '' imgpath; do
            img_rel=${imgpath#${SCREENSHOTS_DIR}/}
            echo "| \"${img_rel}\" |"
          done < <(find "${SCREENSHOTS_DIR}/${lang}" -maxdepth 1 -type f -name "*.png" -print0 | sort -z)
          echo
        fi
      else
        echo "_No PNG screenshots found for ${lang}._"
        echo
      fi
    done < <(find "${SCREENSHOTS_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    # HTML index note/link
    if [[ -f "${SCREENSHOTS_DIR}/screenshots.html" ]]; then
      echo "## HTML Overview"
      echo
      if [[ -n "${BASE_URL}" ]]; then
        echo "Open the HTML index: ${BASE_URL}/screenshots.html"
      else
        echo "The generated HTML index (${SCREENSHOTS_DIR}/screenshots.html) is included in the artifact above."
      fi
      echo
    fi
  else
    echo "_No screenshots directory found. Check the run logs for details._"
  fi
} > "${OUTPUT_MD}"

echo "Wrote ${OUTPUT_MD}" >&2
