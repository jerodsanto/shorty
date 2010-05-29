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

add_action('admin_menu', 'go_shorty');

function go_shorty() {
  add_options_page('Shorty Options', 'Shorty', 'manage_options', 'go_shorty', 'shorty_options');

  if (get_option('shorty_domain') && get_option('shorty_api_key')) {
    add_meta_box('shorty', 'Get Your Shorty', 'shorty_meta_box', 'post','side', 'high');
    add_action('publish_post', 'shorty_generate');
  }
}

function shorty_generate($id) {
  global $post;
  $long_url = urlencode(get_permalink($id));
  $curly = curl_init();
  curl_setopt($curly, CURLOPT_URL, get_option('shorty_domain'));
  curl_setopt($curly, CURLOPT_POST, 2);
  curl_setopt($curly, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($curly, CURLOPT_POSTFIELDS, "url=$long_url&key=".get_option('shorty_api_key'));
  $result = curl_exec($curly);
  curl_close($curly);

  if ($result) {
    add_post_meta($id, 'the_shorty', $result, true) or update_post_meta($id, 'the_shorty', $result);
  }
}

function shorty_meta_box() {
  global $post;
  $shorty = get_post_meta($post->ID, 'the_shorty', true);

  echo '&nbsp;&nbsp;';
  if ($shorty) {
    echo $shorty;
  } else {
    echo 'Publish/Update to generate';
  }
  echo '<br/>';
}

function shorty_options() {
  if (!current_user_can('manage_options'))  {
      wp_die('You do not have sufficient permissions to access this page.');
  }

  echo '<div class="wrap">';
  echo '<h2>Shorty Config</h2>';
  echo '<form method="post" action="options.php">';
  echo wp_nonce_field('update-options');
  echo '<table class="form-table">';
  echo '<tr valign="top">';
  echo '<th scope="row">Shorty Domain</th>';
  echo '<td><input type="text" name="shorty_domain" value="'.get_option('shorty_domain').'"/></td>';
  echo '</tr>';
  echo '<tr valign="top">';
  echo '<th scope="row">API Key</th>';
  echo '<td><input type="text" name="shorty_api_key" value="'.get_option('shorty_api_key').'"/></td>';
  echo '</tr></table>';
  echo '<input type="hidden" name="action" value="update" />';
  echo '<input type="hidden" name="page_options" value="shorty_api_key,shorty_domain" />';
  echo '<p class="submit">';
  echo '<input type="submit" class="button-primary" value="Save Changes" />';
  echo '</p></form></div>';
}
?>
