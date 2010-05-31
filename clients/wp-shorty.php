<?php
/*
Plugin Name: Shorty
Author: Jerod Santo
Description: Interfaces to Shorty for custom short URLs on publish. FTW
Author URI: http://jerodsanto.net
Plugin URI: http://jerodsanto.net
Version: 1.0
License: BSD
*/


/**
* 
*/
class ShortyShortener
{
  public  $options  = null;
  
  private $wpmu     = false;
  private $defaults = array(
      'domain'  => '',
      'api_key' => ''
    );
  
  function __construct()
  {
    // Try to auto-detect WMPU
    $this->wpmu = preg_match('|mu-plugins$|', dirname( __FILE__ ) );
    
    // Initialize Options
    $this->get_options();
    
    add_action('admin_menu', array(&$this, 'setup'));
    add_action('admin_post_update-shorty-options', array(&$this, 'update'));
  }
  
  function setup(){
    add_options_page('Shorty Options', 'Shorty', 'manage_options', 'go_shorty', array(&$this, 'options_page' ));

    if ($this->options['domain'] && $this->options['api_key']) {
      add_meta_box('shorty', 'Get Your Shorty', array(&$this, 'meta_box'), 'post','side', 'high');
      add_action('publish_post', array(&$this, 'generate'));
    }
  }
  
  function update(){
    // Prevent attacks
    check_admin_referer('update-shorty-options');

    $this->options = array_merge($this->defaults, $_POST['shorty_settings']);
    $this->save_options();
    
    wp_redirect( admin_url( 'options-general.php?page=go_shorty&updated=1') );
  }
  
  function get_options(){
    if( $this->wpmu ){
      $options = get_site_option( 'shorty_settings', array() );
    } else {
      $options = get_option( 'shorty_settings', array() );
    }
    $this->options = array_merge( $this->defaults, $options );
  }
  
  function save_options(){
    if($this->wpmu){
      $options = update_site_option( 'shorty_settings', $this->options );
    } else {
      $options = update_option( 'shorty_settings', $this->options );
    }
  }
  
  function options_page(){
    if ( !current_user_can('manage_options') )  {
        wp_die( 'You do not have sufficient permissions to access this page.' );
    } 

    ?>
    <div class="wrap">
      <h2>Shorty Config</h2>
      <form method="post" action="admin-post.php">
        <input type="hidden" name="action" value="update-shorty-options" />
        <?php echo wp_nonce_field('update-shorty-options'); ?>
        <table class="form-table">
          <tr valign="top">
            <th scope="row">Shorty Domain</th>
            <td><input type="text" name="shorty_settings[domain]" value="<?php echo $this->options['domain'] ?>"/></td>
          </tr>
          <tr valign="top">
            <th scope="row">API Key</th>
            <td><input type="text" name="shorty_settings[api_key]" value="<?php echo $this->options['api_key'] ?>"/></td>
          </tr>
        </table>
        <p class="submit">
          <input type="submit" class="button-primary" value="Save Changes" />
        </p>
      </form>
    </div>
    <?php
  }
  
  function meta_box() {
    global $post;
    $shorty = get_post_meta( $post->ID, 'the_shorty', true );

    echo '&nbsp;&nbsp;';
    if ( $shorty ) {
      echo $shorty;
    } else {
      echo 'Publish/Update to generate';
    }
    echo '<br/>';
  }
  
  function generate( $id ) {
    global $post;
    $long_url = urlencode( get_permalink( $id ) );
    $curly = curl_init();
    curl_setopt( $curly, CURLOPT_URL, $this->options['domain'] );
    curl_setopt( $curly, CURLOPT_POST, 2 );
    curl_setopt( $curly, CURLOPT_RETURNTRANSFER, true );
    curl_setopt( $curly, CURLOPT_POSTFIELDS, "url=$long_url&key=" . $this->options['api_key'] );
    $result = curl_exec( $curly );
    curl_close( $curly );

    if ( $result ) {
      update_post_meta($id, 'the_shorty', $result);
    }
  }
  
  # PHP 4 fallback:
  function ShortyShortener(){
    $this->__construct();
  }
}

$shortyShortener = new ShortyShortener();