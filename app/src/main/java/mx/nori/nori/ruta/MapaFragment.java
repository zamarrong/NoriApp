package mx.nori.nori.ruta;

import android.app.Fragment;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.v4.content.ContextCompat;
import android.support.v7.widget.PopupMenu;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapView;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.model.BitmapDescriptor;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.CameraPosition;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import java.util.List;

import im.delight.android.location.SimpleLocation;
import mx.nori.nori.LatLngInterpolator;
import mx.nori.nori.MainActivity;
import mx.nori.nori.MarkerAnimation;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.Ruta;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;
import mx.nori.nori.actividad.ActividadActivity;
import mx.nori.nori.documentos.documento.DocumentoActivity;

public class MapaFragment extends Fragment implements OnMapReadyCallback {

    private SimpleLocation location;
    MapView mapView;
    List<Socio> socios;
    GoogleMap googleMap;
    Marker previousMarker = null;
    Marker currentLocationMarker = null;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_mapa, container, false);
        ((MainActivity) getActivity()).getSupportActionBar().setTitle("Mapa");

        Ruta ruta = Global.getUsuario().ObtenerRuta();

        if (ruta != null) {
            ((MainActivity) getActivity()).getSupportActionBar().setSubtitle(ruta.getNombre());
        }

        location = new SimpleLocation(getActivity());
        if (!location.hasLocationEnabled()) {
            SimpleLocation.openSettings(getActivity());
        }

        location.setListener(new SimpleLocation.Listener() {

            public void onPositionChanged() {
                mostrarMarcador();
            }
        });

        mapView = view.findViewById(R.id.mapView);
        mapView.onCreate(savedInstanceState);
        mapView.onResume();
        mapView.getMapAsync(this);

        socios = Socio.ListarPorRuta();

        return view;
    }

    private BitmapDescriptor bitmapFromVector(Context context, int vectorResId) {
        Drawable vectorDrawable = ContextCompat.getDrawable(getActivity(), vectorResId);
        vectorDrawable.setBounds(0, 0, vectorDrawable.getIntrinsicWidth(), vectorDrawable.getIntrinsicHeight());
        Bitmap bitmap = Bitmap.createBitmap(vectorDrawable.getIntrinsicWidth(), vectorDrawable.getIntrinsicHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        vectorDrawable.draw(canvas);
        return BitmapDescriptorFactory.fromBitmap(bitmap);
    }

    @Override
    public void onMapReady(final GoogleMap googleMap) {
        googleMap.setMapType(GoogleMap.MAP_TYPE_NORMAL);

        googleMap.clear();

        CameraPosition ubicacion = CameraPosition.builder()
                .target(new LatLng(location.getLatitude(), location.getLongitude()))
                .zoom(10)
                .bearing(0)
                .tilt(45)
                .build();

        googleMap.animateCamera(CameraUpdateFactory.newCameraPosition(ubicacion), 5000, null);

        for (Socio socio : socios) {
            if (socio.getLatitud() != 0 && socio.getLongitud() != 0) {
                Marker marker = googleMap.addMarker(new MarkerOptions()
                        .position(new LatLng(socio.getLatitud(), socio.getLongitud()))
                        .title(socio.getNombre()));
                marker.setTag(socio);
            }
        }

        googleMap.setOnMarkerClickListener(new GoogleMap.OnMarkerClickListener() {
            @Override
            public boolean onMarkerClick(Marker marker) {
                final Socio socio = ((Socio) marker.getTag());

                if (socio != null) {
                    ((MainActivity) getActivity()).getSupportActionBar().setSubtitle(socio.getNombre());
                    if (previousMarker != null) {
                        previousMarker.setIcon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED));
                    }
                    marker.setIcon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_BLUE));
                    previousMarker = marker;

                    PopupMenu popup = new PopupMenu(getActivity(), mapView, Gravity.RIGHT, R.attr.actionOverflowMenuStyle, 0);
                    popup.getMenuInflater().inflate(R.menu.socios, popup.getMenu());
                    popup.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
                        @Override
                        public boolean onMenuItemClick(MenuItem item) {
                            switch (item.getItemId()) {
                                case R.id.cotizacion:
                                    Intent intent_cotizacion = new Intent(getActivity(), DocumentoActivity.class);
                                    intent_cotizacion.putExtra("clase", "CO");
                                    intent_cotizacion.putExtra("socio_id", socio.getId());
                                    getActivity().startActivity(intent_cotizacion);
                                    break;
                                case R.id.pedido:
                                    Intent intent_pedido = new Intent(getActivity(), DocumentoActivity.class);
                                    intent_pedido.putExtra("clase", "PE");
                                    intent_pedido.putExtra("socio_id", socio.getId());
                                    getActivity().startActivity(intent_pedido);
                                    break;
                                case R.id.entrega:
                                    Intent intent_entrega = new Intent(getActivity(), DocumentoActivity.class);
                                    intent_entrega.putExtra("clase", "EN");
                                    intent_entrega.putExtra("socio_id", socio.getId());
                                    getActivity().startActivity(intent_entrega);
                                    break;
                                case R.id.factura:
                                    Intent intent_factura = new Intent(getActivity(), DocumentoActivity.class);
                                    intent_factura.putExtra("clase", "FA");
                                    intent_factura.putExtra("socio_id", socio.getId());
                                    getActivity().startActivity(intent_factura);
                                    break;
                                case R.id.actividad:
                                    Intent intent = new Intent(getActivity(), ActividadActivity.class);
                                    intent.putExtra("socio_id", (socio.getId()));
                                    getActivity().startActivity(intent);
                                    break;
                                case R.id.ubicacion:
                                    Uri gmmIntentUri = Uri.parse("google.navigation:q=" + socio.getLatitud() + "," + socio.getLongitud());
                                    Intent mapIntent = new Intent(Intent.ACTION_VIEW, gmmIntentUri);
                                    mapIntent.setPackage("com.google.android.apps.maps");
                                    startActivity(mapIntent);
                                    break;
                            }
                            return true;
                        }
                    });
                    popup.show();
                }
                    
                return true;
            }
        });

        this.googleMap = googleMap;
    }

    private void mostrarMarcador() {
        LatLng latLng = new LatLng(location.getLatitude(), location.getLongitude());
        if (currentLocationMarker == null)
            currentLocationMarker = googleMap.addMarker(new MarkerOptions().icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)).position(latLng));
        else
            MarkerAnimation.animateMarkerToGB(currentLocationMarker, latLng, new LatLngInterpolator.Spherical());
    }

    @Override
    public void onResume() {
        super.onResume();
        location.beginUpdates();
    }

    @Override
    public void onPause() {
        location.endUpdates();
        ((MainActivity) getActivity()).getSupportActionBar().setSubtitle(null);
        super.onPause();
    }
}