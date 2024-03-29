#!/bin/sh

# fail if any called scripts fail
set -e

# include variables
FILENAME=$(basename "$0")
FILENAME_SUFFIX='.setup.sh'
FILENAME_PREFIX=`echo $FILENAME | sed 's#'"${FILENAME_SUFFIX}"'##'`
. ./${FILENAME_PREFIX}.variables.sh  # sourced

# =====================================
#             pre-setup

echo ""
echo "Pre-setup step..."

# check to make sure init was run
cd $INIT_DIR
export VERIFY_SCRIPT_ARGUMENTS="gcp"
. ./verify.sh # use . before calling the script to export any variables
if [ $VERIFY_SCRIPT_RETURN = false ]; then return 1; fi

# make temp directory
cd $STARTING_DIR
if [ -d "$TEMP_DIR" ]; then rm -rf $TEMP_DIR; fi
mkdir $TEMP_DIR
# =====================================

# =====================================
#       base terraform scripts

echo ""
echo "Base terraform scripts step..."

# copy base terraform scripts to temp dir
cd $TERRAFORM_BASE_DIR
cp ./* $TEMP_DIR

# update several values that can't be terraform variables
cd $TEMP_DIR
sed -i -e 's#_TERRAFORM_BUCKET_#'$GCP_TERRAFORM_BUCKET'#g' \
    -e 's#_TERRAFORM_STATE_PREFIX_#'$TERRAFORM_STATE_PREFIX'#g' ./base.tf

# copy in the variables file
if [ -d "$TERRAFORM_VARIABLES_DIR" ]; then
  cd $TERRAFORM_VARIABLES_DIR
  if [ -f "$TERRAFORM_VARIABLES_FILE" ]; then 
    cp $TERRAFORM_VARIABLES_FILE $TEMP_DIR/$TERRAFORM_VARIABLES_FILE
  fi
fi
# =====================================

# =====================================
#             cloud run

echo ""
echo "Cloud run step..."

# run function zip
# copy to temp dir
cd $CONTAINER_DIR
npm run zip
cp container-source.zip $TEMP_DIR

# copy terraform scripts to temp dir
cd $TERRAFORM_CLOUDRUN_DIR
cp -r ./* $TEMP_DIR
# =====================================

# =====================================
#         pre-terraform init

echo ""
echo "Pre-terraform init step..."

# run any scripts that contain "pre-terraform-init" in the name
if [ -d "$TOOL_SCRIPTS" ]; then
  cd $TOOL_SCRIPTS
  for filename in *.pre-terraform-init.*sh; do
    [ -e "$filename" ] || continue
    ./"$filename"
  done
fi
# =====================================

# =====================================
#           terraform init

echo ""
echo "Terraform init step..."

# run terraform init
cd $TEMP_DIR
terraform init
# =====================================

# =====================================
#         pre-terraform apply

echo ""
echo "Pre-terraform apply step..."

# run any scripts that contain "pre-terraform-apply" in the name
if [ -d "$TOOL_SCRIPTS" ]; then
  cd $TOOL_SCRIPTS
  for filename in *.pre-terraform-apply.*sh; do
    [ -e "$filename" ] || continue
    ./"$filename"
  done
fi
# =====================================

# =====================================
#           terraform apply

echo ""
echo "Terraform apply step..."

# run terraform apply
cd $TEMP_DIR
terraform apply ${TERRAFORM_VARIABLES}
# =====================================

# =====================================
#         post terraform apply

echo ""
echo "Post-terraform apply step..."

# run any scripts that contain "post-terraform-apply" in the name
if [ -d "$TOOL_SCRIPTS" ]; then
  cd $TOOL_SCRIPTS
  for filename in *.post-terraform-apply.*sh; do
    [ -e "$filename" ] || continue
    ./"$filename"
  done
fi
# =====================================

# =====================================
#               lastly

# print terraform output as the last thing
echo ""
echo "Terraform output:"
echo ""
cd $TEMP_DIR
terraform output
# =====================================
