#!/bin/bash
# Patch apllying tool template
# v0.1.2
# (c) Copyright 2013. Magento Inc.
#
# DO NOT CHANGE ANY LINE IN THIS FILE.

# 1. Check required system tools
_check_installed_tools() {
    local missed=""

    until [ -z "$1" ]; do
        type -t $1 >/dev/null 2>/dev/null
        if (( $? != 0 )); then
            missed="$missed $1"
        fi
        shift
    done

    echo $missed
}

REQUIRED_UTILS='sed patch'
MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
then
    echo -e "Error! Some required system tools, that are utilized in this sh script, are not installed:\nTool(s) \"$MISSED_REQUIRED_TOOLS\" is(are) missed, please install it(them)."
    exit 1
fi

# 2. Determine bin path for system tools
CAT_BIN=`which cat`
PATCH_BIN=`which patch`
SED_BIN=`which sed`
PWD_BIN=`which pwd`
BASENAME_BIN=`which basename`

BASE_NAME=`$BASENAME_BIN "$0"`

# 3. Help menu
if [ "$1" = "-?" -o "$1" = "-h" -o "$1" = "--help" ]
then
    $CAT_BIN << EOFH
Usage: sh $BASE_NAME [--help] [-R|--revert] [--list]
Apply embedded patch.

-R, --revert    Revert previously applied embedded patch
--list          Show list of applied patches
--help          Show this help message
EOFH
    exit 0
fi

# 4. Get "revert" flag and "list applied patches" flag
REVERT_FLAG=
SHOW_APPLIED_LIST=0
if [ "$1" = "-R" -o "$1" = "--revert" ]
then
    REVERT_FLAG=-R
fi
if [ "$1" = "--list" ]
then
    SHOW_APPLIED_LIST=1
fi

# 5. File pathes
CURRENT_DIR=`$PWD_BIN`/
APP_ETC_DIR=`echo "$CURRENT_DIR""app/etc/"`
APPLIED_PATCHES_LIST_FILE=`echo "$APP_ETC_DIR""applied.patches.list"`

# 6. Show applied patches list if requested
if [ "$SHOW_APPLIED_LIST" -eq 1 ] ; then
    echo -e "Applied/reverted patches list:"
    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -r "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be readable so applied patches list can be shown."
            exit 1
        else
            $SED_BIN -n "/SUP-\|SUPEE-/p" $APPLIED_PATCHES_LIST_FILE
        fi
    else
        echo "<empty>"
    fi
    exit 0
fi

# 7. Check applied patches track file and its directory
_check_files() {
    if [ ! -e "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must exist for proper tool work."
        exit 1
    fi

    if [ ! -w "$APP_ETC_DIR" ]
    then
        echo "ERROR: \"$APP_ETC_DIR\" must be writeable for proper tool work."
        exit 1
    fi

    if [ -e "$APPLIED_PATCHES_LIST_FILE" ]
    then
        if [ ! -w "$APPLIED_PATCHES_LIST_FILE" ]
        then
            echo "ERROR: \"$APPLIED_PATCHES_LIST_FILE\" must be writeable for proper tool work."
            exit 1
        fi
    fi
}

_check_files

# 8. Apply/revert patch
# Note: there is no need to check files permissions for files to be patched.
# "patch" tool will not modify any file if there is not enough permissions for all files to be modified.
# Get start points for additional information and patch data
SKIP_LINES=$((`$SED_BIN -n "/^__PATCHFILE_FOLLOWS__$/=" "$CURRENT_DIR""$BASE_NAME"` + 1))
ADDITIONAL_INFO_LINE=$(($SKIP_LINES - 3))p

_apply_revert_patch() {
    DRY_RUN_FLAG=
    if [ "$1" = "dry-run" ]
    then
        DRY_RUN_FLAG=" --dry-run"
        echo "Checking if patch can be applied/reverted successfully..."
    fi
    PATCH_APPLY_REVERT_RESULT=`$SED_BIN -e '1,/^__PATCHFILE_FOLLOWS__$/d' "$CURRENT_DIR""$BASE_NAME" | $PATCH_BIN $DRY_RUN_FLAG $REVERT_FLAG -p0`
    PATCH_APPLY_REVERT_STATUS=$?
    if [ $PATCH_APPLY_REVERT_STATUS -eq 1 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully.\n\n$PATCH_APPLY_REVERT_RESULT"
        exit 1
    fi
    if [ $PATCH_APPLY_REVERT_STATUS -eq 2 ] ; then
        echo -e "ERROR: Patch can't be applied/reverted successfully."
        exit 2
    fi
}

REVERTED_PATCH_MARK=
if [ -n "$REVERT_FLAG" ]
then
    REVERTED_PATCH_MARK=" | REVERTED"
fi

_apply_revert_patch dry-run
_apply_revert_patch

# 9. Track patch applying result
echo "Patch was applied/reverted successfully."
ADDITIONAL_INFO=`$SED_BIN -n ""$ADDITIONAL_INFO_LINE"" "$CURRENT_DIR""$BASE_NAME"`
APPLIED_REVERTED_ON_DATE=`date -u +"%F %T UTC"`
APPLIED_REVERTED_PATCH_INFO=`echo -n "$APPLIED_REVERTED_ON_DATE"" | ""$ADDITIONAL_INFO""$REVERTED_PATCH_MARK"`
echo -e "$APPLIED_REVERTED_PATCH_INFO\n$PATCH_APPLY_REVERT_RESULT\n\n" >> "$APPLIED_PATCHES_LIST_FILE"

exit 0

SUPEE-10415-1.14.1.0 | EE_1.14.1.0 | v1 | 71e7386c68c286f3fcada8fff09905bf83ef3e88 | Tue Nov 7 17:06:28 2017 +0200 | 6e62f26abcc3eb19bdff29d2aa820ce8dd027630..HEAD

__PATCHFILE_FOLLOWS__
diff --git app/Mage.php app/Mage.php
index e41013f..e9892c5 100644
--- app/Mage.php
+++ app/Mage.php
@@ -805,7 +805,12 @@ final class Mage
         static $loggers = array();
 
         $level  = is_null($level) ? Zend_Log::DEBUG : $level;
-        $file = empty($file) ? 'system.log' : $file;
+        $file = empty($file) ? 'system.log' : basename($file);
+
+        // Validate file extension before save. Allowed file extensions: log, txt, html, csv
+        if (!self::helper('log')->isLogFileExtensionValid($file)) {
+            return;
+        }
 
         try {
             if (!isset($loggers[$file])) {
diff --git app/code/community/OnTap/Merchandiser/Block/Adminhtml/Catalog/Product/List.php app/code/community/OnTap/Merchandiser/Block/Adminhtml/Catalog/Product/List.php
index 1f6ed3f..c65c96f 100644
--- app/code/community/OnTap/Merchandiser/Block/Adminhtml/Catalog/Product/List.php
+++ app/code/community/OnTap/Merchandiser/Block/Adminhtml/Catalog/Product/List.php
@@ -123,8 +123,8 @@ class OnTap_Merchandiser_Block_Adminhtml_Catalog_Product_List extends Mage_Catal
             }
 
             $resource = $product->getResource()->getAttribute($attributeCode);
-            $label = $resource->getFrontendLabel();
-            $value = $resource->getFrontend()->getValue($product);
+            $label = $this->escapeHtml($resource->getFrontendLabel());
+            $value = $this->escapeHtml($resource->getFrontend()->getValue($product));
 
             if ($value) {
                 if ($eavAttribute->getFrontendInput() == 'price') {
diff --git app/code/core/Mage/Adminhtml/Block/Report/Review/Detail.php app/code/core/Mage/Adminhtml/Block/Report/Review/Detail.php
index 02d6864..7ce0d49 100644
--- app/code/core/Mage/Adminhtml/Block/Report/Review/Detail.php
+++ app/code/core/Mage/Adminhtml/Block/Report/Review/Detail.php
@@ -40,7 +40,7 @@ class Mage_Adminhtml_Block_Report_Review_Detail extends Mage_Adminhtml_Block_Wid
         $this->_controller = 'report_review_detail';
 
         $product = Mage::getModel('catalog/product')->load($this->getRequest()->getParam('id'));
-        $this->_headerText = Mage::helper('reports')->__('Reviews for %s', $product->getName());
+        $this->_headerText = Mage::helper('reports')->__('Reviews for %s', $this->escapeHtml($product->getName()));
 
         parent::__construct();
         $this->_removeButton('add');
diff --git app/code/core/Mage/Adminhtml/Block/Report/Tag/Product/Detail.php app/code/core/Mage/Adminhtml/Block/Report/Tag/Product/Detail.php
index 1f91dce..8a9a47a 100644
--- app/code/core/Mage/Adminhtml/Block/Report/Tag/Product/Detail.php
+++ app/code/core/Mage/Adminhtml/Block/Report/Tag/Product/Detail.php
@@ -41,7 +41,7 @@ class Mage_Adminhtml_Block_Report_Tag_Product_Detail extends Mage_Adminhtml_Bloc
 
         $product = Mage::getModel('catalog/product')->load($this->getRequest()->getParam('id'));
 
-        $this->_headerText = Mage::helper('reports')->__('Tags submitted to %s', $product->getName());
+        $this->_headerText = Mage::helper('reports')->__('Tags submitted to %s', $this->escapeHtml($product->getName()));
         parent::__construct();
         $this->_removeButton('add');
         $this->setBackUrl($this->getUrl('*/report_tag/product/'));
diff --git app/code/core/Mage/Adminhtml/Block/Review/Add.php app/code/core/Mage/Adminhtml/Block/Review/Add.php
index 97a7f09..fdcadc2 100644
--- app/code/core/Mage/Adminhtml/Block/Review/Add.php
+++ app/code/core/Mage/Adminhtml/Block/Review/Add.php
@@ -99,7 +99,7 @@ class Mage_Adminhtml_Block_Review_Add extends Mage_Adminhtml_Block_Widget_Form_C
                         } else if( response.id ){
                             $("product_id").value = response.id;
 
-                            $("product_name").innerHTML = \'<a href="' . $this->getUrl('*/catalog_product/edit') . 'id/\' + response.id + \'" target="_blank">\' + response.name + \'</a>\';
+                            $("product_name").innerHTML = \'<a href="' . $this->getUrl('*/catalog_product/edit') . 'id/\' + response.id + \'" target="_blank">\' + response.name.escapeHTML() + \'</a>\';
                         } else if( response.message ) {
                             alert(response.message);
                         }
diff --git app/code/core/Mage/Adminhtml/Block/Review/Edit/Form.php app/code/core/Mage/Adminhtml/Block/Review/Edit/Form.php
index d8f9404..44caa43 100644
--- app/code/core/Mage/Adminhtml/Block/Review/Edit/Form.php
+++ app/code/core/Mage/Adminhtml/Block/Review/Edit/Form.php
@@ -50,9 +50,10 @@ class Mage_Adminhtml_Block_Review_Edit_Form extends Mage_Adminhtml_Block_Widget_
 
         $fieldset->addField('product_name', 'note', array(
             'label'     => Mage::helper('review')->__('Product'),
-            'text'      => '<a href="' . $this->getUrl('*/catalog_product/edit', array('id' => $product->getId())) . '" onclick="this.target=\'blank\'">' . $product->getName() . '</a>'
+            'text'      => '<a href="' . $this->getUrl('*/catalog_product/edit', array('id' => $product->getId())) . '" onclick="this.target=\'blank\'">' . $this->escapeHtml($product->getName()) . '</a>'
         ));
 
+        $customerText = '';
         if ($customer->getId()) {
             $customerText = Mage::helper('review')->__('<a href="%1$s" onclick="this.target=\'blank\'">%2$s %3$s</a> <a href="mailto:%4$s">(%4$s)</a>', $this->getUrl('*/customer/edit', array('id' => $customer->getId(), 'active_tab'=>'review')), $this->escapeHtml($customer->getFirstname()), $this->escapeHtml($customer->getLastname()), $this->escapeHtml($customer->getEmail()));
         } else {
diff --git app/code/core/Mage/Adminhtml/Controller/Action.php app/code/core/Mage/Adminhtml/Controller/Action.php
index d351457..37ceabe 100644
--- app/code/core/Mage/Adminhtml/Controller/Action.php
+++ app/code/core/Mage/Adminhtml/Controller/Action.php
@@ -186,7 +186,7 @@ class Mage_Adminhtml_Controller_Action extends Mage_Core_Controller_Varien_Actio
                     'message' => $_keyErrorMsg
                 )));
             } else {
-                if ($_keyErrorMsg != ''){
+                if (!$_isValidFormKey){
                     Mage::getSingleton('adminhtml/session')->addError($_keyErrorMsg);
                 }
                 $this->_redirect( Mage::getSingleton('admin/session')->getUser()->getStartupPageUrl() );
diff --git app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
index 9e15b7e..ec3eaff 100644
--- app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
+++ app/code/core/Mage/Adminhtml/Model/LayoutUpdate/Validator.php
@@ -142,7 +142,7 @@ class Mage_Adminhtml_Model_LayoutUpdate_Validator extends Zend_Validate_Abstract
     protected function _validateTemplatePath(array $templatePaths)
     {
         foreach ($templatePaths as $path) {
-            if (strpos($path, '../') !== false) {
+            if (strpos($path, '..' . DS) !== false) {
                 throw new Exception();
             }
         }
diff --git app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Filename.php app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Filename.php
index 37e030c..596c09d 100644
--- app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Filename.php
+++ app/code/core/Mage/Adminhtml/Model/System/Config/Backend/Filename.php
@@ -27,10 +27,37 @@
 
 class Mage_Adminhtml_Model_System_Config_Backend_Filename extends Mage_Core_Model_Config_Data
 {
+
+    /**
+     * Config path for system log file.
+     */
+    const DEV_LOG_FILE_PATH = 'dev/log/file';
+
+    /**
+     * Config path for exception log file.
+     */
+    const DEV_LOG_EXCEPTION_FILE_PATH = 'dev/log/exception_file';
+
+    /**
+     * Processing object before save data
+     *
+     * @return Mage_Adminhtml_Model_System_Config_Backend_Filename
+     * @throws Mage_Core_Exception
+     */
     protected function _beforeSave()
     {
-        $value = $this->getValue();
-        $value = basename($value);
+        $value      = $this->getValue();
+        $configPath = $this->getPath();
+        $value      = basename($value);
+
+        // if dev/log setting, validate log file extension.
+        if ($configPath == self::DEV_LOG_FILE_PATH || $configPath == self::DEV_LOG_EXCEPTION_FILE_PATH) {
+            if (!Mage::helper('log')->isLogFileExtensionValid($value)) {
+                throw Mage::exception('Mage_Core', Mage::helper('adminhtml')->__
+                ('Invalid file extension used for log file. Allowed file extensions: log, txt, html, csv'));
+            }
+        }
+
         $this->setValue($value);
         return $this;
     }
diff --git app/code/core/Mage/Api/Helper/Data.php app/code/core/Mage/Api/Helper/Data.php
index bfcaca8..3af0601 100644
--- app/code/core/Mage/Api/Helper/Data.php
+++ app/code/core/Mage/Api/Helper/Data.php
@@ -164,6 +164,49 @@ class Mage_Api_Helper_Data extends Mage_Core_Helper_Abstract
     }
 
     /**
+     * Get wsdl cache id
+     *
+     * @return string
+     */
+    public function getCacheId()
+    {
+        return 'wsdl_config_global_' . md5($this->getServiceUrl('*/*/*'));
+    }
+
+    /**
+     * Get service url
+     *
+     * @param string|null $routePath
+     * @param array|null $routeParams
+     * @param bool $htmlSpecialChars
+     * @return string
+     * @throws Zend_Uri_Exception
+     */
+    public function getServiceUrl($routePath = null, $routeParams = null, $htmlSpecialChars = false)
+    {
+        $request = Mage::app()->getRequest();
+
+        if (is_null($routeParams)) {
+            $routeParams = array();
+        }
+
+        $routeParams['_nosid'] = true;
+
+        /** @var Mage_Core_Model_Url $urlModel */
+        $urlModel = Mage::getSingleton('core/url');
+        $url = $urlModel->getUrl($routePath, $routeParams);
+        $uri = Zend_Uri_Http::fromString($url);
+        $uri->setHost($request->getHttpHost());
+        if (!$urlModel->getRouteFrontName()) {
+            $uri->setPath('/' . trim($request->getBasePath() . '/api.php', '/'));
+        } else {
+            $uri->setPath($request->getBaseUrl() . $request->getPathInfo());
+        }
+
+        return $htmlSpecialChars === true ? htmlspecialchars($uri) : (string)$uri;
+    }
+
+    /**
      * Corrects data representation.
      *
      * @param Object $obj - Link to Object
diff --git app/code/core/Mage/Api/Model/Server/Adapter/Soap.php app/code/core/Mage/Api/Model/Server/Adapter/Soap.php
index bfd6273..2d7e87a 100644
--- app/code/core/Mage/Api/Model/Server/Adapter/Soap.php
+++ app/code/core/Mage/Api/Model/Server/Adapter/Soap.php
@@ -120,7 +120,7 @@ class Mage_Api_Model_Server_Adapter_Soap
                 unset($queryParams['wsdl']);
             }
 
-            $wsdlConfig->setUrl(htmlspecialchars(Mage::getUrl('*/*/*', array('_query'=>$queryParams))));
+            $wsdlConfig->setUrl(Mage::helper('api')->getServiceUrl('*/*/*', array('_query' => $queryParams), true));
             $wsdlConfig->setName('Magento');
             $wsdlConfig->setHandler($this->getHandler());
 
@@ -205,8 +205,8 @@ class Mage_Api_Model_Server_Adapter_Soap
             ->setUseSession(false);
 
         $wsdlUrl = $params !== null
-            ? $urlModel->getUrl('*/*/*', array('_current' => true, '_query' => $params))
-            : $urlModel->getUrl('*/*/*');
+            ? Mage::helper('api')->getServiceUrl('*/*/*', array('_current' => true, '_query' => $params))
+            : Mage::helper('api')->getServiceUrl('*/*/*');
 
         if ( $withAuth ) {
             $phpAuthUser = $this->getController()->getRequest()->getServer('PHP_AUTH_USER', false);
diff --git app/code/core/Mage/Api/Model/Wsdl/Config.php app/code/core/Mage/Api/Model/Wsdl/Config.php
index b7b3a21..c0e4f58 100644
--- app/code/core/Mage/Api/Model/Wsdl/Config.php
+++ app/code/core/Mage/Api/Model/Wsdl/Config.php
@@ -37,7 +37,7 @@ class Mage_Api_Model_Wsdl_Config extends Mage_Api_Model_Wsdl_Config_Base
 
     public function __construct($sourceData=null)
     {
-        $this->setCacheId('wsdl_config_global');
+        $this->setCacheId(Mage::helper('api')->getCacheId());
         parent::__construct($sourceData);
     }
 
diff --git app/code/core/Mage/Api/Model/Wsdl/Config/Base.php app/code/core/Mage/Api/Model/Wsdl/Config/Base.php
index 19c6db8..55681a9 100644
--- app/code/core/Mage/Api/Model/Wsdl/Config/Base.php
+++ app/code/core/Mage/Api/Model/Wsdl/Config/Base.php
@@ -46,15 +46,16 @@ class Mage_Api_Model_Wsdl_Config_Base extends Varien_Simplexml_Config
     {
         $this->_elementClass = 'Mage_Api_Model_Wsdl_Config_Element';
 
-        // remove wsdl parameter from query
         $queryParams = Mage::app()->getRequest()->getQuery();
-        unset($queryParams['wsdl']);
+        if (isset($queryParams['wsdl'])) {
+            unset($queryParams['wsdl']);
+        }
 
         // set up default WSDL template variables
         $this->_wsdlVariables = new Varien_Object(
             array(
                 'name' => 'Magento',
-                'url'  => htmlspecialchars(Mage::getUrl('*/*/*', array('_query' => $queryParams)))
+                'url'  => Mage::helper('api')->getServiceUrl('*/*/*', array('_query' => $queryParams), true)
             )
         );
         parent::__construct($sourceData);
diff --git app/code/core/Mage/Core/Helper/String.php app/code/core/Mage/Core/Helper/String.php
index 157c7d1..fbed4f8 100644
--- app/code/core/Mage/Core/Helper/String.php
+++ app/code/core/Mage/Core/Helper/String.php
@@ -76,6 +76,26 @@ class Mage_Core_Helper_String extends Mage_Core_Helper_Abstract
     }
 
     /**
+     * UnSerialize string
+     * @param $str
+     * @return mixed|null
+     * @throws Exception
+     */
+    public function unserialize($str)
+    {
+        $reader = new Unserialize_Reader_ArrValue('data');
+        $prevChar = null;
+        for ($i = 0; $i < strlen($str); $i++) {
+            $char = $str[$i];
+            $result = $reader->read($char, $prevChar);
+            if (!is_null($result)) {
+                return $result;
+            }
+            $prevChar = $char;
+        }
+    }
+
+    /**
      * Retrieve string length using default charset
      *
      * @param string $string
diff --git app/code/core/Mage/Core/Model/File/Validator/Image.php app/code/core/Mage/Core/Model/File/Validator/Image.php
index bf2d95d0..c9708f1 100644
--- app/code/core/Mage/Core/Model/File/Validator/Image.php
+++ app/code/core/Mage/Core/Model/File/Validator/Image.php
@@ -90,10 +90,7 @@ class Mage_Core_Model_File_Validator_Image
         list($imageWidth, $imageHeight, $fileType) = getimagesize($filePath);
         if ($fileType) {
             if ($this->isImageType($fileType)) {
-                /**
-                 * if 'general/reprocess_images/active' false then skip image reprocessing.
-                 * NOTE: If you turn off images reprocessing, then your upload images process may cause security risks.
-                 */
+                /** if 'general/reprocess_images/active' false then skip image reprocessing. */
                 if (!Mage::getStoreConfigFlag('general/reprocess_images/active')) {
                     return null;
                 }
diff --git app/code/core/Mage/Core/etc/config.xml app/code/core/Mage/Core/etc/config.xml
index fca806d..851fcce 100644
--- app/code/core/Mage/Core/etc/config.xml
+++ app/code/core/Mage/Core/etc/config.xml
@@ -459,6 +459,7 @@
                     </protected>
                 </public_files_valid_paths>
             </file>
+            <!-- NOTE: If you turn off images reprocessing, then your upload images process may cause security risks. -->
             <reprocess_images>
                 <active>1</active>
             </reprocess_images>
diff --git app/code/core/Mage/Core/etc/system.xml app/code/core/Mage/Core/etc/system.xml
index b8f3e1e..7dea8d1 100644
--- app/code/core/Mage/Core/etc/system.xml
+++ app/code/core/Mage/Core/etc/system.xml
@@ -674,7 +674,7 @@
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
                             <show_in_store>1</show_in_store>
-                            <comment>Logging from Mage::log(). File is located in {{base_dir}}/var/log</comment>
+                            <comment>Logging from Mage::log(). File is located in {{base_dir}}/var/log. Allowed file extensions: log, txt, html, csv</comment>
                         </file>
                         <exception_file translate="label comment">
                             <label>Exceptions Log File Name</label>
@@ -684,7 +684,7 @@
                             <show_in_default>1</show_in_default>
                             <show_in_website>1</show_in_website>
                             <show_in_store>1</show_in_store>
-                            <comment>Logging from Mage::logException(). File is located in {{base_dir}}/var/log</comment>
+                            <comment>Logging from Mage::logException(). File is located in {{base_dir}}/var/log. Allowed file extensions: log, txt, html, csv</comment>
                         </exception_file>
                     </fields>
                 </log>
diff --git app/code/core/Mage/Customer/Model/Customer.php app/code/core/Mage/Customer/Model/Customer.php
index 57a6af1..e5a4475 100644
--- app/code/core/Mage/Customer/Model/Customer.php
+++ app/code/core/Mage/Customer/Model/Customer.php
@@ -67,6 +67,16 @@ class Mage_Customer_Model_Customer extends Mage_Core_Model_Abstract
     const CACHE_TAG = 'customer';
 
     /**
+     * Minimum Password Length
+     */
+    const MINIMUM_PASSWORD_LENGTH = 6;
+
+    /**
+     * Maximum Password Length
+     */
+    const MAXIMUM_PASSWORD_LENGTH = 256;
+
+    /**
      * Model event prefix
      *
      * @var string
@@ -838,8 +848,19 @@ class Mage_Customer_Model_Customer extends Mage_Core_Model_Abstract
         if (!$this->getId() && !Zend_Validate::is($password , 'NotEmpty')) {
             $errors[] = Mage::helper('customer')->__('The password cannot be empty.');
         }
-        if (strlen($password) && !Zend_Validate::is($password, 'StringLength', array(6))) {
-            $errors[] = Mage::helper('customer')->__('The minimum password length is %s', 6);
+        if (
+            strlen($password)
+            && !Zend_Validate::is($password, 'StringLength', array(self::MINIMUM_PASSWORD_LENGTH))
+        ) {
+            $errors[] = Mage::helper('customer')
+                ->__('The minimum password length is %s', self::MINIMUM_PASSWORD_LENGTH);
+        }
+        if (
+            strlen($password)
+            && !Zend_Validate::is($password, 'StringLength', array('max' => self::MAXIMUM_PASSWORD_LENGTH))
+        ) {
+            $errors[] = Mage::helper('customer')
+                ->__('Please enter a password with at most %s characters.', self::MAXIMUM_PASSWORD_LENGTH);
         }
         $confirmation = $this->getPasswordConfirmation();
         if ($password != $confirmation) {
diff --git app/code/core/Mage/Eav/Model/Entity/Attribute/Backend/Serialized.php app/code/core/Mage/Eav/Model/Entity/Attribute/Backend/Serialized.php
index 304f11d..17e0f42 100644
--- app/code/core/Mage/Eav/Model/Entity/Attribute/Backend/Serialized.php
+++ app/code/core/Mage/Eav/Model/Entity/Attribute/Backend/Serialized.php
@@ -83,7 +83,8 @@ class Mage_Eav_Model_Entity_Attribute_Backend_Serialized extends Mage_Eav_Model_
         $attrCode = $this->getAttribute()->getAttributeCode();
         if ($object->getData($attrCode)) {
             try {
-                $unserialized = unserialize($object->getData($attrCode));
+                $unserialized = Mage::helper('core/string')
+                    ->unserialize($object->getData($attrCode));
                 $object->setData($attrCode, $unserialized);
             } catch (Exception $e) {
                 $object->unsetData($attrCode);
diff --git app/code/core/Mage/Log/Helper/Data.php app/code/core/Mage/Log/Helper/Data.php
index ce64be6..63d59ff 100644
--- app/code/core/Mage/Log/Helper/Data.php
+++ app/code/core/Mage/Log/Helper/Data.php
@@ -29,5 +29,26 @@
  */
 class Mage_Log_Helper_Data extends Mage_Core_Helper_Abstract
 {
+    /**
+     * Allowed extensions that can be used to create a log file
+     */
+    private $_allowedFileExtensions = array('log', 'txt', 'html', 'csv');
 
+
+    /**
+     * Checking if file extensions is allowed. If passed then return true.
+     *
+     * @param $file
+     * @return bool
+     */
+    public function isLogFileExtensionValid($file)
+    {
+        $result = false;
+        $validatedFileExtension = pathinfo($file, PATHINFO_EXTENSION);
+        if ($validatedFileExtension && in_array($validatedFileExtension, $this->_allowedFileExtensions)) {
+            $result = true;
+        }
+
+        return $result;
+    }
 }
diff --git app/code/core/Mage/Rule/Model/Abstract.php app/code/core/Mage/Rule/Model/Abstract.php
index a71d994..ac02dd6 100644
--- app/code/core/Mage/Rule/Model/Abstract.php
+++ app/code/core/Mage/Rule/Model/Abstract.php
@@ -176,7 +176,7 @@ abstract class Mage_Rule_Model_Abstract extends Mage_Core_Model_Abstract
         if ($this->hasConditionsSerialized()) {
             $conditions = $this->getConditionsSerialized();
             if (!empty($conditions)) {
-                $conditions = unserialize($conditions);
+                $conditions = Mage::helper('core/unserializeArray')->unserialize($conditions);
                 if (is_array($conditions) && !empty($conditions)) {
                     $this->_conditions->loadArray($conditions);
                 }
@@ -215,7 +215,7 @@ abstract class Mage_Rule_Model_Abstract extends Mage_Core_Model_Abstract
         if ($this->hasActionsSerialized()) {
             $actions = $this->getActionsSerialized();
             if (!empty($actions)) {
-                $actions = unserialize($actions);
+                $actions = Mage::helper('core/unserializeArray')->unserialize($actions);
                 if (is_array($actions) && !empty($actions)) {
                     $this->_actions->loadArray($actions);
                 }
diff --git app/code/core/Mage/Sales/Block/Adminhtml/Billing/Agreement/Grid.php app/code/core/Mage/Sales/Block/Adminhtml/Billing/Agreement/Grid.php
index ed7a9e6..b79e1d2 100644
--- app/code/core/Mage/Sales/Block/Adminhtml/Billing/Agreement/Grid.php
+++ app/code/core/Mage/Sales/Block/Adminhtml/Billing/Agreement/Grid.php
@@ -94,7 +94,8 @@ class Mage_Sales_Block_Adminhtml_Billing_Agreement_Grid extends Mage_Adminhtml_B
         $this->addColumn('customer_email', array(
             'header'            => Mage::helper('sales')->__('Customer Email'),
             'index'             => 'customer_email',
-            'type'              => 'text'
+            'type'              => 'text',
+            'escape'            => true
         ));
 
         $this->addColumn('customer_firstname', array(
diff --git app/code/core/Zend/Form/Decorator/Form.php app/code/core/Zend/Form/Decorator/Form.php
new file mode 100644
index 0000000..511c520
--- /dev/null
+++ app/code/core/Zend/Form/Decorator/Form.php
@@ -0,0 +1,143 @@
+<?php
+/**
+ * Zend Framework
+ *
+ * LICENSE
+ *
+ * This source file is subject to the new BSD license that is bundled
+ * with this package in the file LICENSE.txt.
+ * It is also available through the world-wide-web at this URL:
+ * http://framework.zend.com/license/new-bsd
+ * If you did not receive a copy of the license and are unable to
+ * obtain it through the world-wide-web, please send an email
+ * to license@zend.com so we can send you a copy immediately.
+ *
+ * @category   Zend
+ * @package    Zend_Form
+ * @subpackage Decorator
+ * @copyright  Copyright (c) 2005-2015 Zend Technologies USA Inc. (http://www.zend.com)
+ * @license    http://framework.zend.com/license/new-bsd     New BSD License
+ */
+
+/** Zend_Form_Decorator_Abstract */
+#require_once 'Zend/Form/Decorator/Abstract.php';
+
+/**
+ * This class replaces default Zend_Form_Decorator_Form because of problem described in MPERF-9707/MPERF-9769
+ * The only difference between current class and original one is overwritten implementation of render method
+ *
+ * Zend_Form_Decorator_Form
+ *
+ * Render a Zend_Form object.
+ *
+ * Accepts following options:
+ * - separator: Separator to use between elements
+ * - helper: which view helper to use when rendering form. Should accept three
+ *   arguments, string content, a name, and an array of attributes.
+ *
+ * Any other options passed will be used as HTML attributes of the form tag.
+ *
+ * @category   Zend
+ * @package    Zend_Form
+ * @subpackage Decorator
+ * @copyright  Copyright (c) 2005-2015 Zend Technologies USA Inc. (http://www.zend.com)
+ * @license    http://framework.zend.com/license/new-bsd     New BSD License
+ * @version    $Id$
+ */
+class Zend_Form_Decorator_Form extends Zend_Form_Decorator_Abstract
+{
+    /**
+     * Default view helper
+     * @var string
+     */
+    protected $_helper = 'form';
+
+    /**
+     * Set view helper for rendering form
+     *
+     * @param  string $helper
+     * @return Zend_Form_Decorator_Form
+     */
+    public function setHelper($helper)
+    {
+        $this->_helper = (string) $helper;
+        return $this;
+    }
+
+    /**
+     * Get view helper for rendering form
+     *
+     * @return string
+     */
+    public function getHelper()
+    {
+        if (null !== ($helper = $this->getOption('helper'))) {
+            $this->setHelper($helper);
+            $this->removeOption('helper');
+        }
+        return $this->_helper;
+    }
+
+    /**
+     * Retrieve decorator options
+     *
+     * Assures that form action and method are set, and sets appropriate
+     * encoding type if current method is POST.
+     *
+     * @return array
+     */
+    public function getOptions()
+    {
+        if (null !== ($element = $this->getElement())) {
+            if ($element instanceof Zend_Form) {
+                $element->getAction();
+                $method = $element->getMethod();
+                if ($method == Zend_Form::METHOD_POST) {
+                    $this->setOption('enctype', 'application/x-www-form-urlencoded');
+                }
+                foreach ($element->getAttribs() as $key => $value) {
+                    $this->setOption($key, $value);
+                }
+            } elseif ($element instanceof Zend_Form_DisplayGroup) {
+                foreach ($element->getAttribs() as $key => $value) {
+                    $this->setOption($key, $value);
+                }
+            }
+        }
+
+        if (isset($this->_options['method'])) {
+            $this->_options['method'] = strtolower($this->_options['method']);
+        }
+
+        return $this->_options;
+    }
+
+    /**
+     * Render a form
+     *
+     * Replaces $content entirely from currently set element.
+     *
+     * @param  string $content
+     * @return string
+     */
+    public function render($content)
+    {
+        $form    = $this->getElement();
+        $view    = $form->getView();
+        if (null === $view) {
+            return $content;
+        }
+
+        $helper        = $this->getHelper();
+        $attribs       = $this->getOptions();
+        $name          = $form->getFullyQualifiedName();
+        $attribs['id'] = $form->getId();
+        if ($helper == 'unserialize') {
+            $filter = new Varien_Filter_FormElementName(true);
+            if($filter->filter($name) != $name){
+                throw new Zend_Form_Exception(sprintf('Invalid element name:"%s"', $name));
+            }
+        }
+        return $view->$helper($name, $attribs, $content);
+    }
+}
diff --git app/design/adminhtml/default/default/template/backup/dialogs.phtml app/design/adminhtml/default/default/template/backup/dialogs.phtml
index 69ba286..521106e 100644
--- app/design/adminhtml/default/default/template/backup/dialogs.phtml
+++ app/design/adminhtml/default/default/template/backup/dialogs.phtml
@@ -132,7 +132,7 @@
                                 <td class="value">
                                     <!-- This is a dummy hidden field to trick firefox from auto filling the password -->
                                     <input type="password" class="input-text no-display" name="dummy" id="dummy" />
-                                    <input type="password" name="ftp_pass" id="ftp_pass" autocomplete="new-pawwsord">
+                                    <input type="password" name="ftp_pass" id="ftp_pass" autocomplete="new-password">
                                 </td>
                             </tr>
                             <tr>
diff --git app/design/adminhtml/default/default/template/merchandiser/smartmerch/tab.phtml app/design/adminhtml/default/default/template/merchandiser/smartmerch/tab.phtml
index c8c519e..274fda9 100644
--- app/design/adminhtml/default/default/template/merchandiser/smartmerch/tab.phtml
+++ app/design/adminhtml/default/default/template/merchandiser/smartmerch/tab.phtml
@@ -87,7 +87,7 @@
                                 <?php echo Mage::helper('merchandiser')->__("Hero Products") ?> :
                             </td>
                             <td class="value">
-                                <input type="text" class="input-text" value="<?php echo $merchandiserValues['heroproducts']; ?>" id="group_198merchandiser_heroproducts" name="merchandiser[heroproducts]" style="width:350px" />
+                                <input type="text" class="input-text" value="<?php echo $this->escapeHtml($merchandiserValues['heroproducts']); ?>" id="group_198merchandiser_heroproducts" name="merchandiser[heroproducts]" style="width:350px" />
                                 <p class="note">
                                     <?php echo $this->__("Enter a comma separated list of SKUs that will always be displayed at the top of your category") ?>
                                 </p>
diff --git app/design/adminhtml/default/default/template/sales/billing/agreement/view/tab/info.phtml app/design/adminhtml/default/default/template/sales/billing/agreement/view/tab/info.phtml
index fb392a8..1f335a0 100644
--- app/design/adminhtml/default/default/template/sales/billing/agreement/view/tab/info.phtml
+++ app/design/adminhtml/default/default/template/sales/billing/agreement/view/tab/info.phtml
@@ -41,7 +41,7 @@
                     <th><?php echo $this->__('Customer'); ?></th>
                     <td>
                         <a href="<?php echo $this->getCustomerUrl(); ?>">
-                            <?php echo $this->getCustomerEmail() ?>
+                            <?php echo $this->escapeHtml($this->getCustomerEmail()) ?>
                         </a>
                     </td>
                 </tr>
diff --git app/design/adminhtml/default/default/template/xmlconnect/edit/tab/content.phtml app/design/adminhtml/default/default/template/xmlconnect/edit/tab/content.phtml
index acdc967..cadea79 100644
--- app/design/adminhtml/default/default/template/xmlconnect/edit/tab/content.phtml
+++ app/design/adminhtml/default/default/template/xmlconnect/edit/tab/content.phtml
@@ -107,7 +107,7 @@
         init : function() {
             $('content_pages').update('');
             <?php foreach($this->getPages() as $page): ?>
-                this.pageOptions += '<option value="<?php echo $helper->jsQuoteEscape($page['value']) ?>"><?php echo $helper->jsQuoteEscape($page['label']) ?></option>';
+                this.pageOptions += '<option value="<?php echo $helper->jsQuoteEscape($page['value']) ?>"><?php echo $helper->quoteEscape($page['label']) ?></option>';
             <?php endforeach; ?>
         },
         showPage : function(node, label, idValue) {
diff --git app/design/adminhtml/default/default/template/xmlconnect/edit/tab/design/image_edit.phtml app/design/adminhtml/default/default/template/xmlconnect/edit/tab/design/image_edit.phtml
index 0e72423..2a5c481 100644
--- app/design/adminhtml/default/default/template/xmlconnect/edit/tab/design/image_edit.phtml
+++ app/design/adminhtml/default/default/template/xmlconnect/edit/tab/design/image_edit.phtml
@@ -50,7 +50,7 @@
                         <option value=""><?php echo $this->__('CMS Pages haven\'t been found.'); ?></option>
                     <?php endif;?>
                     <?php foreach ($pages as $page):?>
-                        <option value="<?php echo $page['value']; ?>"><?php echo $page['label']; ?></option>
+                        <option value="<?php echo $page['value']; ?>"><?php echo Mage::helper('core')->quoteEscape($page['label']); ?></option>
                     <?php endforeach;?>
                 </select>
             </div>
diff --git app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/scripts.phtml app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/scripts.phtml
index 10fca42..5e54875 100644
--- app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/scripts.phtml
+++ app/design/frontend/enterprise/default/template/giftcardaccount/onepage/payment/scripts.phtml
@@ -32,6 +32,9 @@ function enablePaymentMethods(free) {
         var elements = Form.getElements(this.form);
         var methodName = '';
         for (var i=0; i < elements.length; i++) {
+            if (elements[i].name == 'form_key') {
+                continue;
+            }
             if (elements[i].name == 'payment[method]'
                 || elements[i].name == 'payment[use_customer_balance]'
                 || elements[i].name == 'payment[use_reward_points]'
diff --git app/design/frontend/rwd/enterprise/template/giftcardaccount/onepage/payment/scripts.phtml app/design/frontend/rwd/enterprise/template/giftcardaccount/onepage/payment/scripts.phtml
index d823297..95c2bca 100644
--- app/design/frontend/rwd/enterprise/template/giftcardaccount/onepage/payment/scripts.phtml
+++ app/design/frontend/rwd/enterprise/template/giftcardaccount/onepage/payment/scripts.phtml
@@ -32,6 +32,9 @@ function enablePaymentMethods(free) {
         var elements = Form.getElements(this.form);
         var methodName = '';
         for (var i=0; i < elements.length; i++) {
+            if (elements[i].name == 'form_key') {
+                continue;
+            }
             if (elements[i].name == 'payment[method]'
                 || elements[i].name == 'payment[use_customer_balance]'
                 || elements[i].name == 'payment[use_reward_points]'
diff --git app/locale/en_US/Mage_Adminhtml.csv app/locale/en_US/Mage_Adminhtml.csv
index c30b6d2..e961b5f 100644
--- app/locale/en_US/Mage_Adminhtml.csv
+++ app/locale/en_US/Mage_Adminhtml.csv
@@ -1,6 +1,7 @@
 " The customer does not exist in the system anymore."," The customer does not exist in the system anymore."
 " [deleted]"," [deleted]"
 " and "," and "
+"Invalid file extension used for log file. Allowed file extensions: log, txt, html, csv", "Invalid file extension used for log file. Allowed file extensions: log, txt, html, csv"
 "%s (Default Template from Locale)","%s (Default Template from Locale)"
 "%s cache type(s) disabled.","%s cache type(s) disabled."
 "%s cache type(s) enabled.","%s cache type(s) enabled."
diff --git app/locale/en_US/Mage_Customer.csv app/locale/en_US/Mage_Customer.csv
index 29c66ea..58a4f2c 100644
--- app/locale/en_US/Mage_Customer.csv
+++ app/locale/en_US/Mage_Customer.csv
@@ -26,6 +26,7 @@
 "Address Templates","Address Templates"
 "Addresses","Addresses"
 "Admin","Admin"
+"Please enter a password with at most %s characters.","Please enter a password with at most %s characters."
 "All","All"
 "All Store Views","All Store Views"
 "All countries","All countries"
diff --git js/mage/adminhtml/backup.js js/mage/adminhtml/backup.js
index f107a34..f9d58f7 100644
--- js/mage/adminhtml/backup.js
+++ js/mage/adminhtml/backup.js
@@ -97,7 +97,8 @@ AdminBackup.prototype = {
 
         $$('#ftp-credentials-container input').each(function(item) {
             if (item.name == 'ftp_path') return;
-            $('use_ftp').checked ? item.addClassName('required-entry') : item.removeClassName('required-entry');
+            $('use_ftp').checked && item.name != 'dummy' ?
+                item.addClassName('required-entry') : item.removeClassName('required-entry');
         });
 
         $(divId).show().setStyle({
diff --git lib/Varien/Filter/FormElementName.php lib/Varien/Filter/FormElementName.php
new file mode 100644
index 0000000..888e1e9
--- /dev/null
+++ lib/Varien/Filter/FormElementName.php
@@ -0,0 +1,35 @@
+<?php
+/**
+ * {license_notice}
+ *
+ * @copyright   {copyright}
+ * @license     {license_link}
+ */
+
+
+class Varien_Filter_FormElementName extends Zend_Filter_Alnum
+{
+    /**
+     * Defined by Zend_Filter_Interface
+     *
+     * Returns the string $value, removing all but alphabetic (including -_;) and digit characters
+     *
+     * @param  string $value
+     * @return string
+     */
+    public function filter($value)
+    {
+        $whiteSpace = $this->allowWhiteSpace ? '\s' : '';
+        if (!self::$_unicodeEnabled) {
+            // POSIX named classes are not supported, use alternative a-zA-Z0-9 match
+            $pattern = '/[^a-zA-Z0-9\[\];_\-' . $whiteSpace . ']/';
+        } else if (self::$_meansEnglishAlphabet) {
+            //The Alphabet means english alphabet.
+            $pattern = '/[^a-zA-Z0-9\[\];_\-'  . $whiteSpace . ']/u';
+        } else {
+            //The Alphabet means each language's alphabet.
+            $pattern = '/[^\p{L}\p{N}\[\];_\-' . $whiteSpace . ']/u';
+        }
+        return preg_replace($pattern, '', (string) $value);
+    }
+}
